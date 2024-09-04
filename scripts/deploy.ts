import { ethers } from "hardhat";

async function main() {
  // Get the deployer's address
  const [deployer] = await ethers.getSigners();
  const deployerAddress = deployer.address;

  // Deploy the CreatorPlatformContract using the AuroraToken address, initial token price, and the deployer's address
  const creatorContract = await ethers.deployContract(
    "CreatorPlatformContract",
    [
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
