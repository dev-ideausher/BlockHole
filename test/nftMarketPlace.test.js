describe("Nft Marketplace Unit Tests", function () {
  let nftMarketplace, nftMarketplaceContract;
  const PRICE = ethers.utils.parseEther("");

  beforeEach(async () => {
    accounts = await ethers.getSigners(); // could also do with getNamedAccounts
    deployer = accounts[0];
    user = accounts[1];
    await deployments.fixture(["all"]);
    nftMarketplaceContract = await ethers.getContract("NFTMarketplace");
    nftMarketplace = nftMarketplaceContract.connect(deployer);
    nftMarketplace = nftMarketplaceContract.connect(deployer);
  });

  describe("", function () {});
  describe("", function () {});
  describe("", function () {});
  describe("", function () {});
  describe("", function () {});
});
