# ⚽ GoalOracle — AI-Powered World Cup 2026 Prediction Market

> Live on X Layer Mainnet · Built for X Cup Hackathon 2026

## What is it?

GoalOracle lets football fans predict World Cup 2026 match outcomes, stake OKB, and win from a shared pool — all on-chain on X Layer. An AI oracle powered by Claude gives real-time match analysis and betting insights to every player.

## Live Contract

- **Address:** 0x6f2fad74009Ed11A764d6fd3871E52C585861E92
- **Network:** X Layer Mainnet (Chain ID 196)
- **Explorer:** https://www.oklink.com/xlayer/address/0x6f2fad74009Ed11A764d6fd3871E52C585861E92

## Live Demo

https://goaloracle.vercel.app

## How It Works

1. Connect your OKX Wallet
2. Browse open World Cup matches
3. Pick an outcome — Home Win / Draw / Away Win
4. Stake any amount of OKB (minimum 0.001)
5. If you're right, you win a proportional share of the losing pool
6. Earn points and streaks — climb the on-chain leaderboard

## Payout Formula

```
profit = (losingPool × yourStake / winningPool) × 0.95
payout = yourStake + profit
```

5% goes to the protocol. Everything else goes to winners. Automatically. No middleman.

## Points & Streaks

| Action | Points |
|---|---|
| Place a prediction | +10 |
| Correct prediction | +100 |
| Each streak level bonus | +25 |

## Tech Stack

- **Smart Contract:** Solidity 0.8.20 deployed on X Layer Mainnet
- **Frontend:** Vanilla HTML + JavaScript
- **AI Oracle:** Claude API (Anthropic) for live match insights
- **Blockchain Library:** ethers.js v6
- **Wallet:** OKX Wallet / MetaMask

## Contract Features

- Match lifecycle: create → open → close → resolve → cancelled
- Proportional payout pool (parimutuel model)
- On-chain leaderboard with streak multipliers
- Full refund logic for cancelled matches
- estimatePayout() view function for pre-trade transparency
- Checks-effects-interactions pattern (no reentrancy risk)

## Project Structure

```
goaloracle/
├── contracts/
│   └── GoalOracle.sol       # Main smart contract
├── scripts/
│   └── deploy.js            # Deployment script
├── test/
│   └── GoalOracle.test.js   # Full test suite
├── goaloracle_frontend.html  # Complete frontend dApp
├── hardhat.config.js         # X Layer network config
└── package.json
```

## Deploying Yourself

```bash
git clone https://github.com/YOURUSERNAME/goaloracle
cd goaloracle
npm install
cp .env.example .env
# Add your private key to .env
npx hardhat run scripts/deploy.js --network xlayer
```

## Built For

X Cup Hackathon 2026 · X Layer (OKX ZK-EVM) · May 2026

## License

MIT
