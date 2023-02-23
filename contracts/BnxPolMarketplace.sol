// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTMarketplace is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 listingFee = 0.01 ether;
    address payable NFTMarketplaceOwner;
    address bnxToken;

    mapping(uint256 => NFTItemMarketSpecs) idToNFTItemMarketSpecs;

    struct NFTItemMarketSpecs {
        uint256 tokenId;
        address payable creator;
        uint256 royaltyPercent;
        address seller;
        address payable owner;
        uint256 priceinPol;
        uint256 priceinBnx;
        bool listedInPol;
        bool listedInBnx;
        bool sold;
    }

    event createdNFT(
        uint256 indexed tokenId,
        address indexed creator,
        uint256 indexed royaltyPercent
    );

    event ListingNFT(
        uint256 indexed tokenId,
        address indexed creator,
        uint256 royaltyPercent,
        address seller,
        address owner,
        uint256 indexed price,
        bool sold,
        bool listedInPol,
        bool listedInBnx
    );

    event ListingCancelled(
        uint256 indexed tokenId,
        address indexed creator,
        address indexed seller,
        address owner
    );

    event buyingNFT(
        uint256 indexed tokenId,
        address creator,
        address indexed seller,
        address indexed owner
    );

    event MarketplaceBalanceWithdrew(string action, uint256 balance);

    event ListingChargeUpdated(string action, uint256 listingCharge);

    modifier onlyOwner() {
        require(
            msg.sender == NFTMarketplaceOwner,
            "only owner of the marketplace can perform this action"
        );
        _;
    }

    constructor(address _marketplaceOwner, address _token)
        ERC721("BlockHole Tokens", "BHT")
    {
        NFTMarketplaceOwner = payable(_marketplaceOwner);
        bnxToken = _token;
    }

    function updatelistingFee(uint256 _listingFee) external onlyOwner {
        listingFee = _listingFee;

        emit ListingChargeUpdated("Listing Charge Updated", listingFee);
    }

    function getlistingFee() public view returns (uint256) {
        return listingFee;
    }

    function createNFT(string memory tokenUri, uint256 royaltyPercent)
        external
    {
        require(royaltyPercent <= 10, "Royalty should be less than 10%");
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, tokenUri);
        idToNFTItemMarketSpecs[tokenId].tokenId = tokenId;
        idToNFTItemMarketSpecs[tokenId].creator = payable(msg.sender);
        idToNFTItemMarketSpecs[tokenId].seller = address(0);
        idToNFTItemMarketSpecs[tokenId].owner = payable(msg.sender);
        idToNFTItemMarketSpecs[tokenId].royaltyPercent = royaltyPercent;
        idToNFTItemMarketSpecs[tokenId].sold = false;

        emit createdNFT(
            tokenId,
            msg.sender,
            idToNFTItemMarketSpecs[tokenId].royaltyPercent
        );
    }

    function listNFTInPol(uint256 tokenId, uint256 price) external payable {
        require(price > 0, "Price cannot be 0");
        require(msg.value == listingFee, "Must be equal to listing price");
        require(
            IERC721(address(this)).ownerOf(tokenId) == msg.sender,
            "Only the owner of nft can sell their nft."
        );

        idToNFTItemMarketSpecs[tokenId].seller = payable(msg.sender);
        idToNFTItemMarketSpecs[tokenId].priceinPol = price;
        idToNFTItemMarketSpecs[tokenId].owner = payable(address(this));
        idToNFTItemMarketSpecs[tokenId].listedInPol = true;
        idToNFTItemMarketSpecs[tokenId].listedInBnx = false;
        idToNFTItemMarketSpecs[tokenId].sold = false;

        _transfer(msg.sender, address(this), tokenId);

        emit ListingNFT(
            tokenId,
            idToNFTItemMarketSpecs[tokenId].creator,
            idToNFTItemMarketSpecs[tokenId].royaltyPercent,
            msg.sender,
            address(this),
            price,
            false,
            true,
            false
        );
    }

    function listNFTInBnx(uint256 tokenId, uint256 price) external payable {
        require(price > 0, "Price cannot be 0");
        require(msg.value == listingFee, "Must be equal to listing price");
        require(
            IERC721(address(this)).ownerOf(tokenId) == msg.sender,
            "Only the owner of nft can sell their nft."
        );

        idToNFTItemMarketSpecs[tokenId].seller = payable(msg.sender);
        idToNFTItemMarketSpecs[tokenId].listedInBnx = true;
        idToNFTItemMarketSpecs[tokenId].listedInPol = false;
        idToNFTItemMarketSpecs[tokenId].priceinBnx = price;
        idToNFTItemMarketSpecs[tokenId].owner = payable(address(this));

        _transfer(msg.sender, address(this), tokenId);

        emit ListingNFT(
            tokenId,
            idToNFTItemMarketSpecs[tokenId].creator,
            idToNFTItemMarketSpecs[tokenId].royaltyPercent,
            msg.sender,
            address(this),
            price,
            false,
            false,
            true
        );
    }

    function cancelListing(uint256 tokenId) external {
        address seller = idToNFTItemMarketSpecs[tokenId].seller;
        require(
            idToNFTItemMarketSpecs[tokenId].seller == msg.sender,
            "Only the seller can cancel the listing"
        );
        idToNFTItemMarketSpecs[tokenId].owner = payable(msg.sender);
        idToNFTItemMarketSpecs[tokenId].seller = address(0);
        idToNFTItemMarketSpecs[tokenId].listedInBnx = false;
        idToNFTItemMarketSpecs[tokenId].listedInPol = false;

        _transfer(address(this), seller, tokenId);

        emit ListingCancelled(
            tokenId,
            idToNFTItemMarketSpecs[tokenId].creator,
            msg.sender,
            msg.sender
        );
    }

    function buyNFTInPol(uint256 tokenId) external payable {
        require(
            idToNFTItemMarketSpecs[tokenId].listedInPol == true,
            "Not listed in Pol"
        );
        uint256 price = idToNFTItemMarketSpecs[tokenId].priceinPol;
        address seller = idToNFTItemMarketSpecs[tokenId].seller;
        uint256 royaltyAmount = ((idToNFTItemMarketSpecs[tokenId]
            .royaltyPercent * msg.value) / 100);
        uint256 SellerPayout = price - royaltyAmount;
        require(msg.value == price, "value is not equal to nft purchase price");
        idToNFTItemMarketSpecs[tokenId].owner = payable(msg.sender);
        idToNFTItemMarketSpecs[tokenId].sold = true;
        idToNFTItemMarketSpecs[tokenId].seller = address(0);
        idToNFTItemMarketSpecs[tokenId].listedInBnx = false;
        idToNFTItemMarketSpecs[tokenId].listedInPol = false;
        _transfer(address(this), msg.sender, tokenId);
        payable(idToNFTItemMarketSpecs[tokenId].creator).transfer(
            royaltyAmount
        );
        payable(seller).transfer(SellerPayout);

        emit buyingNFT(
            tokenId,
            idToNFTItemMarketSpecs[tokenId].creator,
            seller,
            msg.sender
        );
    }

    function buyNFTInBnx(uint256 tokenId) external {
        require(
            idToNFTItemMarketSpecs[tokenId].listedInBnx == true,
            "Not sold in bnx"
        );
        uint256 price = idToNFTItemMarketSpecs[tokenId].priceinBnx;
        address seller = idToNFTItemMarketSpecs[tokenId].seller;
        uint256 royaltyAmount = ((idToNFTItemMarketSpecs[tokenId]
            .royaltyPercent * price) / 100);
        uint256 SellerPayout = price - royaltyAmount;
        idToNFTItemMarketSpecs[tokenId].owner = payable(msg.sender);
        idToNFTItemMarketSpecs[tokenId].seller = address(0);
        idToNFTItemMarketSpecs[tokenId].sold = true;
        idToNFTItemMarketSpecs[tokenId].listedInBnx = false;
        idToNFTItemMarketSpecs[tokenId].listedInPol = false;
        _transfer(address(this), msg.sender, tokenId);

        // approval need to be done before this can be done
        IERC20(bnxToken).transferFrom(msg.sender, address(this), price);
        IERC20(bnxToken).transfer(seller, SellerPayout);
        IERC20(bnxToken).transfer(
            idToNFTItemMarketSpecs[tokenId].creator,
            royaltyAmount
        );

        emit buyingNFT(
            tokenId,
            idToNFTItemMarketSpecs[tokenId].creator,
            seller,
            msg.sender
        );
    }

    function withdrawListingCommission() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Zero balance in the account.");
        payable(NFTMarketplaceOwner).transfer(address(this).balance);

        emit MarketplaceBalanceWithdrew(
            "Marketplace balance withdrew",
            balance
        );
    }

    function contractBalance() public view returns (uint) {
        return address(this).balance;
    }

    function fetchCreatorNft(uint tokenId) public view returns (address) {
        return idToNFTItemMarketSpecs[tokenId].creator;
    }

    function fetchRoyaltyPercentofNft(uint tokenId) public view returns (uint) {
        return idToNFTItemMarketSpecs[tokenId].royaltyPercent;
    }
}
