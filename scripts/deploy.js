const hre = require("hardhat");

async function main() {
  // const Initial_Token_Price_In_Cent = 50;
  // const CPToken = await hre.ethers.deployContract("CPToken", [
  //   Initial_Token_Price_In_Cent,
  // ]);

  // await CPToken.waitForDeployment();

  // console.log(
  //   `CPToken  with initial price ${Initial_Token_Price_In_Cent} cent deployed to ${CPToken.target}`
  // );

  const Initial_Token_Price_In_Cent = 50;
  const inital_token_supply_in_Wei = 1000000000000000n;
  const _max_allowance_amount = 100000000000n;

  const Game = await hre.ethers.deployContract("Game", [
    Initial_Token_Price_In_Cent,
    inital_token_supply_in_Wei,
    _max_allowance_amount,
  ]);

  await Game.waitForDeployment();

  console.log(`Game  contract deployed to ${Game.target}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
