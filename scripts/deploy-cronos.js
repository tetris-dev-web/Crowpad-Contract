// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  let deployCronosToken = false;
  let deployCrowpadTokenFactory = false;
  let deployCrowpadSaleFactory = true;
  let deployCrowpadAirdropper = false;
  let deployCrowpadLocker = false;

  // CronosToken
  if (deployCronosToken) {
    const CronosToken = await hre.ethers.getContractFactory("CronosToken");
    const cronosToken = await CronosToken.deploy(
      "Crowpad Token",
      "CROW",
      10000000000
    );
    await cronosToken.deployed();
    console.log("CronosToken deployed to:", cronosToken.address);

    const CrowpadSimpleTokenFactory = await hre.ethers.getContractFactory(
      "CrowpadSimpleTokenFactory"
    );
    const crowpadSimpleTokenFactory = await CrowpadSimpleTokenFactory.deploy("0x43ad0f0585659a68faA72FE276e48B9d2a23B117");
    await crowpadSimpleTokenFactory.deployed();
    console.log(
      "CrowpadSimpleTokenFactory deployed to:",
      crowpadSimpleTokenFactory.address
    );
  }

  // CrowpadTokenFactory
  if (deployCrowpadTokenFactory) {
    const CrowpadTokenFactory = await hre.ethers.getContractFactory(
      "CrowpadTokenFactory"
    );
    const crowpadTokenFactory = await CrowpadTokenFactory.deploy("0x43ad0f0585659a68faA72FE276e48B9d2a23B117");
    await crowpadTokenFactory.deployed();
    console.log("CrowpadTokenFactory deployed to:", crowpadTokenFactory.address);
  }

  // CrowpadSaleFactory
  if (deployCrowpadSaleFactory) {
    const CrowpadSaleFactory = await hre.ethers.getContractFactory(
      "CrowpadSaleFactory"
    );
    const crowpadSaleFactory = await CrowpadSaleFactory.deploy("0x43ad0f0585659a68faA72FE276e48B9d2a23B117");
    await crowpadSaleFactory.deployed();
    console.log("CrowpadSaleFactory deployed to:", crowpadSaleFactory.address);
  }

  // CrowpadAirdropper
  if (deployCrowpadAirdropper) {
    const CrowpadAirdropper = await hre.ethers.getContractFactory(
      "CrowpadAirdropper"
    );
    const crowpadAirdropper = await CrowpadAirdropper.deploy();
    await crowpadAirdropper.deployed();
    console.log("CrowpadAirdropper deployed to:", crowpadAirdropper.address);
  
    const CrowpadFlexTierStakingContract = await hre.ethers.getContractFactory(
      "CrowpadFlexTierStakingContract"
    );
    const crowpadFlexTierStakingContract =
      await CrowpadFlexTierStakingContract.deploy(
        "0x44DA42feC06528d827d737E3B276AF6036913044",
        "0x9502E2F202dDEC76BB1331Ec56a8a1a05B17d0Ac",
        "0x059cF17C3B04C7C0624dd332Ba81936aDD9c842B"
      );
    await crowpadFlexTierStakingContract.deployed();
    console.log(
      "CrowpadFlexTierStakingContract deployed to:",
      crowpadFlexTierStakingContract.address
    );
  
    const CrowpadBronzeTierStakingContract = await hre.ethers.getContractFactory(
      "CrowpadBronzeTierStakingContract"
    );
    const crowpadBronzeTierStakingContract =
      await CrowpadBronzeTierStakingContract.deploy(
        "0x44DA42feC06528d827d737E3B276AF6036913044",
        "0x9502E2F202dDEC76BB1331Ec56a8a1a05B17d0Ac",
        "0x059cF17C3B04C7C0624dd332Ba81936aDD9c842B"
      );
    await crowpadBronzeTierStakingContract.deployed();
    console.log(
      "CrowpadBronzeTierStakingContract deployed to:",
      crowpadBronzeTierStakingContract.address
    );
  
    const CrowpadSilverTierStakingContract = await hre.ethers.getContractFactory(
      "CrowpadSilverTierStakingContract"
    );
    const crowpadSilverTierStakingContract =
      await CrowpadSilverTierStakingContract.deploy(
        "0x44DA42feC06528d827d737E3B276AF6036913044",
        "0x9502E2F202dDEC76BB1331Ec56a8a1a05B17d0Ac",
        "0x059cF17C3B04C7C0624dd332Ba81936aDD9c842B"
      );
    await crowpadSilverTierStakingContract.deployed();
    console.log(
      "CrowpadSilverTierStakingContract deployed to:",
      crowpadSilverTierStakingContract.address
    );
  
    const CrowpadGoldTierStakingContract = await hre.ethers.getContractFactory(
      "CrowpadGoldTierStakingContract"
    );
    const crowpadGoldTierStakingContract =
      await CrowpadGoldTierStakingContract.deploy(
        "0x44DA42feC06528d827d737E3B276AF6036913044",
        "0x9502E2F202dDEC76BB1331Ec56a8a1a05B17d0Ac",
        "0x059cF17C3B04C7C0624dd332Ba81936aDD9c842B"
      );
    await crowpadGoldTierStakingContract.deployed();
    console.log(
      "CrowpadGoldTierStakingContract deployed to:",
      crowpadGoldTierStakingContract.address
    );
  }
  
  // CrowpadLocker
  if (deployCrowpadLocker) {
    const CrowpadLocker = await hre.ethers.getContractFactory(
      "CrowpadLocker"
    );
    const crowpadLocker = await CrowpadLocker.deploy(
      "0x44DA42feC06528d827d737E3B276AF6036913044",
      "0x9502E2F202dDEC76BB1331Ec56a8a1a05B17d0Ac",
      "0x059cF17C3B04C7C0624dd332Ba81936aDD9c842B"
    );
    await crowpadLocker.deployed();
    console.log("CrowpadLocker deployed to:", crowpadLocker.address);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
