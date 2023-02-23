// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTMarketplace is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 public listingFee = 0.01 ether;
    address payable NFTMarketplaceOwner;

    mapping(uint256 => NFTItemMarketSpecs) idToNFTItemMarketSpecs;

    struct NFTItemMarketSpecs {
        uint256 tokenId;
        address creator;
        uint256 royaltyPercent;
        address seller;
        address owner;
        uint256 price;
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
        uint256 listingFee
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

    constructor(address _marketplaceOwner) ERC721("BlockHole Tokens", "BHT") {
        NFTMarketplaceOwner = payable(_marketplaceOwner);
    }

    function updatelistingFee(uint256 _listingFee) external onlyOwner {
        listingFee = _listingFee;

        emit ListingChargeUpdated("Listing Charge Updated", listingFee);
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
        idToNFTItemMarketSpecs[tokenId].creator = msg.sender;
        idToNFTItemMarketSpecs[tokenId].seller = address(0);
        idToNFTItemMarketSpecs[tokenId].owner = msg.sender;
        idToNFTItemMarketSpecs[tokenId].royaltyPercent = royaltyPercent;
        idToNFTItemMarketSpecs[tokenId].sold = false;

        emit createdNFT(
            tokenId,
            msg.sender,
            idToNFTItemMarketSpecs[tokenId].royaltyPercent
        );
    }

    function listNFT(uint256 tokenId, uint256 price) external payable {
        require(price > 0, "Price cannot be 0");
        require(msg.value == listingFee, "Must be equal to listing price");
        require(
            IERC721(address(this)).ownerOf(tokenId) == msg.sender,
            "Only the owner of nft list the nft for sale"
        );

        idToNFTItemMarketSpecs[tokenId].seller = msg.sender;
        idToNFTItemMarketSpecs[tokenId].price = price;
        idToNFTItemMarketSpecs[tokenId].owner = address(this);
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
            msg.value
        );
    }

    function cancelListing(uint256 tokenId) external {
        address seller = idToNFTItemMarketSpecs[tokenId].seller;
        require(
            idToNFTItemMarketSpecs[tokenId].seller == msg.sender,
            "Only the seller can cancel the listing"
        );
        idToNFTItemMarketSpecs[tokenId].owner = msg.sender;
        idToNFTItemMarketSpecs[tokenId].seller = address(0);

        _transfer(address(this), seller, tokenId);

        emit ListingCancelled(
            tokenId,
            idToNFTItemMarketSpecs[tokenId].creator,
            msg.sender,
            msg.sender
        );
    }

    function buyNFT(uint256 tokenId) external payable {
        uint256 price = idToNFTItemMarketSpecs[tokenId].price;
        address seller = idToNFTItemMarketSpecs[tokenId].seller;
        uint256 royaltyAmount = ((idToNFTItemMarketSpecs[tokenId]
            .royaltyPercent * msg.value) / 100);
        uint256 SellerPayout = price - royaltyAmount;
        require(msg.value == price, "value is not equal to nft purchase price");
        require(
            msg.sender != NFTMarketplaceOwner && msg.sender != seller,
            "seller and marketplace owner cannot buy the nft"
        );
        idToNFTItemMarketSpecs[tokenId].owner = msg.sender;
        idToNFTItemMarketSpecs[tokenId].sold = true;
        idToNFTItemMarketSpecs[tokenId].seller = address(0);
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

    function withdrawListingCommission() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Zero balance in the account.");
        NFTMarketplaceOwner.transfer(address(this).balance);

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

    function getNFTDetails(uint tokenId)
        external
        view
        returns (NFTItemMarketSpecs memory)
    {
        NFTItemMarketSpecs memory NFTDetails = NFTItemMarketSpecs(
            idToNFTItemMarketSpecs[tokenId].tokenId,
            idToNFTItemMarketSpecs[tokenId].creator,
            idToNFTItemMarketSpecs[tokenId].royaltyPercent,
            idToNFTItemMarketSpecs[tokenId].seller,
            IERC721(address(this)).ownerOf(tokenId),
            idToNFTItemMarketSpecs[tokenId].price,
            idToNFTItemMarketSpecs[tokenId].sold
        );

        return NFTDetails;
    }
}
