npx- Get balance of ERC20: `npx oz balance --erc20 0xdac17f958d2ee523a2206206994597c13d831ec7` (usdt) 
or `npx oz balance --erc20 0x64fB96d0395f6bf105F35233911e3dF2C5bf4Ce8 0x2cb3c989d47a87a2bf1a49b9868b1ea533570e2c` (xbt)
- When switch between wallet private key, you should clean up deployed contract by run `npx oz remove` to avoid error: `Cannot set a proxy implementation to a non-contract address`
- if errors occur, change to use Ganache instead of Hardhat or delete folder `.openzeppelin`
