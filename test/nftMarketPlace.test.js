const { expect } = require("chai");

describe("NFTMarketplace contract", function () {
  let NFTMarketplace;
  let nftMarketplace;
  let owner, addr1, addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
    NFTMarketplace = await ethers.getContractFactory("NFTMarketplace");
    nftMarketplace = await NFTMarketplace.deploy(owner.address);
  });

  //tests associated with deployment
  describe("Deployment", function () {
    it("should deploy the contract", async function () {
      expect(await nftMarketplace.address).to.exist;
    });

    it("should assign the name and symbol of the contract", async function () {
      expect(await nftMarketplace.name()).to.equal("BlockHole Tokens");
      expect(await nftMarketplace.symbol()).to.equal("BHT");
    });

    it("should assign the listing price to 0.001 ether", async function () {
      expect(await nftMarketplace.listingFee()).to.equal(
        ethers.utils.parseEther("0.01")
      );
    });
  });

  //tests associated with listing price
  describe("Listing fee", function () {
    it("should fail if anyone else other than marketplace owner tries to update", async function () {
      await expect(
        nftMarketplace
          .connect(addr1)
          .updateListingFee(ethers.utils.parseEther("0.03"))
      ).to.be.revertedWith(
        "only owner of the marketplace can perform this action"
      );
    });

    it("should update the listing fee only when all conditions are met", async function () {
      const initialListingFee = await nftMarketplace.listingFee();

      await nftMarketplace
        .connect(owner)
        .updateListingFee(ethers.utils.parseEther("0.03"));
      const updatedListingFee = await nftMarketplace.listingFee();
      expect(initialListingFee).to.not.equal(updatedListingFee);
      expect(updatedListingFee).to.equal(ethers.utils.parseEther("0.03"));
    });
  });

  //function to call createNFT() from smart contract
  const createNFT = async (tokenURI, royalty) => {
    const tx = await nftMarketplace.connect(addr1).createNFT(tokenURI, royalty);
    const receipt = await tx.wait();
    const tokenId = receipt.events[0].args.tokenId;
    return tokenId;
  };

  //function to create and list NFT for sell
  const createAndSellNFT = async (tokenURI, royalty, price, options) => {
    const tokenId = await createNFT(tokenURI, royalty);
    const tx = await nftMarketplace
      .connect(addr1)
      .listNFT(tokenId, price, options);
    await tx.wait();
    return tokenId;
  };

  //tests associated with creating,selling,cancelling listing and buying NFT
  describe("Create, sell, cancel listing, buy NFT", function () {
    //NFT creation
    it("should fail  if royalty is more than 10%", async function () {
      const tokenURI = "www.ideausher.com";
      const royalty = 15;

      await expect(createNFT(tokenURI, royalty)).to.be.revertedWith(
        "Royalty should be less than 10%"
      );
    });

    it("should create NFT only when all conditions are met", async function () {
      const tokenURI = "www.ideausher.com";
      const royalty = 7;
      const tokenId = await createNFT(tokenURI, royalty);

      expect(await nftMarketplace.tokenURI(tokenId)).to.equal(tokenURI);
      expect(await nftMarketplace.ownerOf(tokenId)).to.equal(addr1.address);
    });

    //NFT listing for sale
    it("should fail if price is 0", async function () {
      const tokenURI = "www.ideausher.com";
      const royalty = 7;
      const price = ethers.utils.parseEther("0");
      const options = { value: ethers.utils.parseEther("0.01") };

      await expect(
        createAndSellNFT(tokenURI, royalty, price, options)
      ).to.revertedWith("Price cannot be 0");
    });

    it("should fail if msg.value is not equal to listing price", async function () {
      const tokenURI = "www.ideausher.com";
      const royalty = 7;
      const price = ethers.utils.parseEther("0.05");
      const options = { value: ethers.utils.parseEther("0.009") };

      await expect(
        createAndSellNFT(tokenURI, royalty, price, options)
      ).to.be.revertedWith("Must be equal to listing fee");
    });

    it("should fail if anyone else other than owner of NFT tries to sell", async function () {
      const tokenURI = "www.ideausher.com";
      const royalty = 7;
      const tokenId = await createNFT(tokenURI, royalty);

      const price = ethers.utils.parseEther("0.05");

      await expect(
        nftMarketplace
          .connect(addr2)
          .listNFT(tokenId, price, { value: ethers.utils.parseEther("0.01") })
      ).to.be.revertedWith("Only the owner of NFT can sell it");
    });

    it("should list NFT for sale and transfer listing fee to contract", async function () {
      const tokenURI = "www.ideausher.com";
      const royalty = 7;
      const tokenId = await createNFT(tokenURI, royalty);

      const initialContractBalance = await ethers.provider.getBalance(
        nftMarketplace.address
      );

      const price = ethers.utils.parseEther("0.05");
      const txn = await nftMarketplace
        .connect(addr1)
        .listNFT(tokenId, price, { value: ethers.utils.parseEther("0.01") });
      const sellReceipt = await txn.wait();
      const args = sellReceipt.events[0].args;

      const finalContractBalance = await ethers.provider.getBalance(
        nftMarketplace.address
      );

      expect(args.tokenId).to.equal(tokenId);
      expect(args.to).to.equal(nftMarketplace.address);
      expect(await nftMarketplace.ownerOf(tokenId)).to.equal(
        nftMarketplace.address
      );
      expect(finalContractBalance.sub(initialContractBalance)).to.equal(
        await nftMarketplace.listingFee()
      );
    });

    //cancelling listing
    it("should fail  if anyone else other than seller tries to cancel", async function () {
      const tokenURI = "www.ideausher.com";
      const royalty = 7;
      const price = ethers.utils.parseEther("0.05");
      const options = { value: ethers.utils.parseEther("0.01") };

      const tokenId = await createAndSellNFT(tokenURI, royalty, price, options);

      await expect(
        nftMarketplace.connect(addr2).cancelListing(tokenId)
      ).to.be.revertedWith("Only the seller can cancel the listing");
    });

    it("should cancel listing only when all conditions are met", async function () {
      const tokenURI = "www.ideausher.com";
      const royalty = 7;
      const price = ethers.utils.parseEther("0.05");
      const options = { value: ethers.utils.parseEther("0.01") };

      const tokenId = await createAndSellNFT(tokenURI, royalty, price, options);

      const tx = await nftMarketplace.connect(addr1).cancelListing(tokenId);
      const receipt = await tx.wait();
      const args = receipt.events[0].args;
      expect(args.to).to.equal(addr1.address);
    });

    //buying NFT
    it("should fail to buy NFT if msg.value is less than price", async function () {
      const tokenURI = "www.ideausher.com";
      const royalty = 7;
      const price = ethers.utils.parseEther("0.05");
      const options = { value: ethers.utils.parseEther("0.01") };

      const tokenId = await createAndSellNFT(tokenURI, royalty, price, options);

      await expect(
        nftMarketplace
          .connect(addr2)
          .buyNFT(tokenId, { value: ethers.utils.parseEther("0.03") })
      ).to.be.revertedWith("Ether sent along should be equal to price");
    });

    it("should buy NFT and transfer money to creator and seller", async function () {
      const tokenURI = "www.ideausher.com";
      const royalty = 7;
      const price = ethers.utils.parseEther("0.05");
      const options = { value: ethers.utils.parseEther("0.01") };

      const tokenId = await createAndSellNFT(tokenURI, royalty, price, options);

      const initialCreatorSellerBalance = await addr1.getBalance();
      const initialBuyerBalance = await addr2.getBalance();

      const tx = await nftMarketplace
        .connect(addr2)
        .buyNFT(tokenId, { value: ethers.utils.parseEther("0.05") });
      const receipt = await tx.wait();
      const gas = receipt.gasUsed.mul(receipt.effectiveGasPrice);
      const args = receipt.events[0].args;

      const finalCreatorSellerBalance = await addr1.getBalance();
      const finalBuyerBalance = await addr2.getBalance();

      expect(
        finalCreatorSellerBalance.sub(initialCreatorSellerBalance)
      ).to.equal(price);
      expect(finalBuyerBalance).to.equal(
        initialBuyerBalance.sub(gas.add(price))
      );

      expect(args.tokenId).to.equal(tokenId);
      expect(args.to).to.equal(addr2.address);
      expect(await nftMarketplace.ownerOf(tokenId)).to.equal(addr2.address);
    });
  });

  //withdraw listing commission
  describe("withdraw listing commission", function () {
    it("should fail if anyone else other than the marketplace owner tries to withdraw", async function () {
      const tokenURI = "www.ideausher.com";
      const royalty = 7;
      const price = ethers.utils.parseEther("0.05");
      const options = { value: ethers.utils.parseEther("0.01") };

      await createAndSellNFT(tokenURI, royalty, price, options);

      await expect(
        nftMarketplace.connect(addr2).withdrawListingCommission()
      ).to.be.revertedWith(
        "only owner of the marketplace can perform this action"
      );
    });

    it("should withdraw only when all conditions are met", async function () {
      const tokenURI = "www.ideausher.com";
      const royalty = 7;
      const price = ethers.utils.parseEther("0.05");
      const options = { value: ethers.utils.parseEther("0.01") };

      await createAndSellNFT(tokenURI, royalty, price, options);

      const contractBalance = await ethers.provider.getBalance(
        nftMarketplace.address
      );
      const initialOwnerBalance = await owner.getBalance();

      const tx = await nftMarketplace
        .connect(owner)
        .withdrawListingCommission();
      const receipt = await tx.wait();

      const finalOwnerBalance = await owner.getBalance();

      const gas = receipt.gasUsed.mul(receipt.effectiveGasPrice);

      const transferred = finalOwnerBalance.add(gas).sub(initialOwnerBalance);
      expect(transferred).to.equal(contractBalance);
    });
  });
});
