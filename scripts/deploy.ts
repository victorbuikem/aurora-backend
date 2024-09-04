import { ethers } from "hardhat";

async function main() {
  // Get the deployer's address
  const [deployer] = await ethers.getSigners();
  const deployerAddress = deployer.address;

  // Deploy the AuroraToken contract with the deployer's address
  const aurToken = await ethers.deployContract("AuroraToken", [
    deployerAddress,
  ]);

  await aurToken.waitForDeployment();
  const aurTokenAddress = aurToken.target;

  console.log("AuroraToken Contract Deployed at " + aurTokenAddress);

  // Set the initial token price (replace '1' with the actual price if needed)
  const initialTokenPrice = "1";

  // Deploy the CreatorPlatformContract using the AuroraToken address, initial token price, and the deployer's address
  const creatorContract = await ethers.deployContract(
    "CreatorPlatformContract",
    [
      aurTokenAddress, // AuroraToken contract address
      initialTokenPrice, // Initial token price
      deployerAddress, // Deployer's address (owner)
    ]
  );

  await creatorContract.waitForDeployment();
  console.log(
    "CreatorPlatformContract Contract Deployed at " + creatorContract.target
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
