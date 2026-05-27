// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title GoalOracle
 * @notice World Cup 2026 prediction market on X Layer
 * @dev Deployed on X Layer (Chain ID: 196), native token OKB
 */
contract GoalOracle {

    // ─── Types ───────────────────────────────────────────────────────────────

    enum Outcome { NONE, HOME, DRAW, AWAY }
    enum MatchStatus { OPEN, LOCKED, SETTLED, CANCELLED }

    struct Match {
        string homeTeam;
        string awayTeam;
        string matchLabel;
        uint64 kickoffTime;
        MatchStatus status;
        Outcome result;
        uint256 totalStaked;
        uint256[3] outcomeStakes; // [HOME-1, DRAW-1, AWAY-1]
    }

    struct Prediction {
        Outcome outcome;
        uint256 stake;
        bool claimed;
    }

    // ─── State ───────────────────────────────────────────────────────────────

    address public owner;
    uint256 public matchCount;
    uint256 public constant PLATFORM_FEE_BPS = 200; // 2%
    uint256 public constant MIN_STAKE = 0.001 ether; // 0.001 OKB

    mapping(uint256 => Match) public matches;
    mapping(uint256 => mapping(address => Prediction)) public predictions;
    mapping(address => uint256) public points;
    mapping(address => uint256) public totalPredictions;
    mapping(address => uint256) public correctPredictions;

    // ─── Events ──────────────────────────────────────────────────────────────

    event MatchCreated(uint256 indexed matchId, string homeTeam, string awayTeam, uint64 kickoffTime);
    event PredictionPlaced(uint256 indexed matchId, address indexed user, Outcome outcome, uint256 stake);
    event MatchSettled(uint256 indexed matchId, Outcome result);
    event RewardClaimed(uint256 indexed matchId, address indexed user, uint256 amount, uint256 pointsEarned);
    event MatchCancelled(uint256 indexed matchId);

    // ─── Modifiers ───────────────────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier matchExists(uint256 matchId) {
        require(matchId < matchCount, "Match does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // ─── Admin Functions ──────────────────────────────────────────────────────

    function createMatch(
        string calldata homeTeam,
        string calldata awayTeam,
        string calldata matchLabel,
        uint64 kickoffTime
    ) external onlyOwner returns (uint256 matchId) {
        require(kickoffTime > block.timestamp, "Kickoff must be in the future");
        matchId = matchCount++;
        matches[matchId] = Match({
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            matchLabel: matchLabel,
            kickoffTime: kickoffTime,
            status: MatchStatus.OPEN,
            result: Outcome.NONE,
            totalStaked: 0,
            outcomeStakes: [uint256(0), uint256(0), uint256(0)]
        });
        emit MatchCreated(matchId, homeTeam, awayTeam, kickoffTime);
    }

    function lockMatch(uint256 matchId) external onlyOwner matchExists(matchId) {
        Match storage m = matches[matchId];
        require(m.status == MatchStatus.OPEN, "Match not open");
        m.status = MatchStatus.LOCKED;
    }

    function settleMatch(uint256 matchId, Outcome result) external onlyOwner matchExists(matchId) {
        require(result != Outcome.NONE, "Invalid result");
        Match storage m = matches[matchId];
        require(m.status == MatchStatus.LOCKED, "Match not locked");
        m.status = MatchStatus.SETTLED;
        m.result = result;
        emit MatchSettled(matchId, result);
    }

    function cancelMatch(uint256 matchId) external onlyOwner matchExists(matchId) {
        Match storage m = matches[matchId];
        require(m.status == MatchStatus.OPEN || m.status == MatchStatus.LOCKED, "Cannot cancel");
        m.status = MatchStatus.CANCELLED;
        emit MatchCancelled(matchId);
    }

    function withdrawFees(address payable to, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        to.transfer(amount);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
    }

    // ─── User Functions ───────────────────────────────────────────────────────

    function predict(uint256 matchId, Outcome outcome) external payable matchExists(matchId) {
        require(outcome != Outcome.NONE, "Invalid outcome");
        require(msg.value >= MIN_STAKE, "Stake too low");
        Match storage m = matches[matchId];
        require(m.status == MatchStatus.OPEN, "Predictions closed");
        require(block.timestamp < m.kickoffTime, "Match already started");
        require(predictions[matchId][msg.sender].stake == 0, "Already predicted");

        predictions[matchId][msg.sender] = Prediction({
            outcome: outcome,
            stake: msg.value,
            claimed: false
        });

        m.totalStaked += msg.value;
        m.outcomeStakes[uint256(outcome) - 1] += msg.value;
        totalPredictions[msg.sender]++;

        emit PredictionPlaced(matchId, msg.sender, outcome, msg.value);
    }

    function claimReward(uint256 matchId) external matchExists(matchId) {
        Match storage m = matches[matchId];
        Prediction storage p = predictions[matchId][msg.sender];
        require(p.stake > 0, "No prediction");
        require(!p.claimed, "Already claimed");
        p.claimed = true;

        if (m.status == MatchStatus.CANCELLED) {
            payable(msg.sender).transfer(p.stake);
            return;
        }

        require(m.status == MatchStatus.SETTLED, "Not settled yet");

        if (p.outcome != m.result) {
            return; // Wrong prediction, no payout
        }

        correctPredictions[msg.sender]++;

        uint256 winningPool = m.outcomeStakes[uint256(m.result) - 1];
        uint256 totalPool = m.totalStaked;
        uint256 grossPayout = (p.stake * totalPool) / winningPool;
        uint256 fee = (grossPayout * PLATFORM_FEE_BPS) / 10_000;
        uint256 netPayout = grossPayout - fee;

        // Points scale with the implied odds (bigger upsets = more points)
        uint256 oddsX100 = (totalPool * 100) / winningPool;
        uint256 earnedPoints = (100 * oddsX100) / 100;
        points[msg.sender] += earnedPoints;

        payable(msg.sender).transfer(netPayout);
        emit RewardClaimed(matchId, msg.sender, netPayout, earnedPoints);
    }

    // ─── View Functions ───────────────────────────────────────────────────────

    function getMatch(uint256 matchId) external view matchExists(matchId) returns (
        string memory homeTeam,
        string memory awayTeam,
        string memory matchLabel,
        uint64 kickoffTime,
        MatchStatus status,
        Outcome result,
        uint256 totalStaked,
        uint256 homeStaked,
        uint256 drawStaked,
        uint256 awayStaked
    ) {
        Match storage m = matches[matchId];
        return (m.homeTeam, m.awayTeam, m.matchLabel, m.kickoffTime, m.status, m.result,
                m.totalStaked, m.outcomeStakes[0], m.outcomeStakes[1], m.outcomeStakes[2]);
    }

    function getPrediction(uint256 matchId, address user) external view returns (
        Outcome outcome, uint256 stake, bool claimed
    ) {
        Prediction storage p = predictions[matchId][user];
        return (p.outcome, p.stake, p.claimed);
    }

    function getPlayerStats(address user) external view returns (
        uint256 pts, uint256 total, uint256 correct, uint256 winRateBps
    ) {
        pts = points[user];
        total = totalPredictions[user];
        correct = correctPredictions[user];
        winRateBps = total > 0 ? (correct * 10_000) / total : 0;
    }

    function estimatePayout(uint256 matchId, Outcome outcome, uint256 stakeAmount)
        external view matchExists(matchId) returns (uint256 estimatedPayout)
    {
        Match storage m = matches[matchId];
        uint256 winPool = m.outcomeStakes[uint256(outcome) - 1] + stakeAmount;
        uint256 totalPool = m.totalStaked + stakeAmount;
        estimatedPayout = (stakeAmount * totalPool) / winPool;
    }

    function getOdds(uint256 matchId) external view matchExists(matchId) returns (
        uint256 homeOddsX100, uint256 drawOddsX100, uint256 awayOddsX100
    ) {
        Match storage m = matches[matchId];
        uint256 total = m.totalStaked;
        if (total == 0) return (0, 0, 0);
        homeOddsX100 = m.outcomeStakes[0] > 0 ? (total * 100) / m.outcomeStakes[0] : 0;
        drawOddsX100 = m.outcomeStakes[1] > 0 ? (total * 100) / m.outcomeStakes[1] : 0;
        awayOddsX100 = m.outcomeStakes[2] > 0 ? (total * 100) / m.outcomeStakes[2] : 0;
    }

    receive() external payable {}
}
