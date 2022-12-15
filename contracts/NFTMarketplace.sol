// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTMarketplace is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;

    uint256 listingFee = 0.01 ether;
    address payable NFTMarketplaceOwner;

    mapping(uint256 => NFTItemMarketSpecs) private idToNFTItemMarketSpecs;

    struct NFTItemMarketSpecs {
        uint256 tokenId;
        address payable creator;
        uint256 royaltyPercent;
        address seller;
        address payable owner;
        uint256 price;
        bool sold;
        bool cancelledPreviousListing;
        bool relisted;
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
        bool sold
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

    constructor() ERC721("BlockHole Tokens", "BHT") {
        NFTMarketplaceOwner = payable(msg.sender);
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
        idToNFTItemMarketSpecs[tokenId].relisted = false;
        idToNFTItemMarketSpecs[tokenId].cancelledPreviousListing = false;

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
            idToNFTItemMarketSpecs[tokenId].owner == msg.sender,
            "Only the owner of nft can sell his nft"
        );

        idToNFTItemMarketSpecs[tokenId].seller = payable(msg.sender);
        idToNFTItemMarketSpecs[tokenId].price = price;
        idToNFTItemMarketSpecs[tokenId].owner = payable(address(this));
        if (
            idToNFTItemMarketSpecs[tokenId].cancelledPreviousListing == false &&
            idToNFTItemMarketSpecs[tokenId].relisted == true
        ) {
            _itemsSold.decrement();
        }
        _transfer(msg.sender, address(this), tokenId);

        emit ListingNFT(
            tokenId,
            idToNFTItemMarketSpecs[tokenId].creator,
            idToNFTItemMarketSpecs[tokenId].royaltyPercent,
            msg.sender,
            address(this),
            price,
            false
        );
    }

    // function changeRoyaltyPercentByCreator() external {}

    function cancelListing(uint256 tokenId) external {
        address seller = idToNFTItemMarketSpecs[tokenId].seller;
        require(
            idToNFTItemMarketSpecs[tokenId].seller == msg.sender,
            "Only the seller can cancel the listing"
        );
        idToNFTItemMarketSpecs[tokenId].owner = payable(msg.sender);
        idToNFTItemMarketSpecs[tokenId].seller = address(0);
        idToNFTItemMarketSpecs[tokenId].cancelledPreviousListing = true;

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
        idToNFTItemMarketSpecs[tokenId].owner = payable(msg.sender);
        idToNFTItemMarketSpecs[tokenId].sold = true;
        idToNFTItemMarketSpecs[tokenId].cancelledPreviousListing = false;
        idToNFTItemMarketSpecs[tokenId].relisted = true;
        idToNFTItemMarketSpecs[tokenId].seller = address(0);
        _itemsSold.increment();
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
        payable(NFTMarketplaceOwner).transfer(address(this).balance);

        emit MarketplaceBalanceWithdrew(
            "Marketplace balance withdrew",
            balance
        );
    }

    function contractBalance() public view returns (uint) {
        return address(this).balance;
    }

    function fetchAllUnsoldNFTs()
        public
        view
        returns (NFTItemMarketSpecs[] memory)
    {
        uint256 itemCount = _tokenIds.current();
        uint256 unsoldItemCount = _tokenIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

        NFTItemMarketSpecs[] memory items = new NFTItemMarketSpecs[](
            unsoldItemCount
        );
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToNFTItemMarketSpecs[i + 1].owner == address(this)) {
                uint256 currentId = i + 1;
                NFTItemMarketSpecs storage currentItem = idToNFTItemMarketSpecs[
                    currentId
                ];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function fetchMyNFTs() public view returns (NFTItemMarketSpecs[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToNFTItemMarketSpecs[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        NFTItemMarketSpecs[] memory items = new NFTItemMarketSpecs[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToNFTItemMarketSpecs[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                NFTItemMarketSpecs storage currentItem = idToNFTItemMarketSpecs[
                    currentId
                ];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function fetchMyListedNFTs()
        external
        view
        returns (NFTItemMarketSpecs[] memory)
    {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToNFTItemMarketSpecs[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        NFTItemMarketSpecs[] memory items = new NFTItemMarketSpecs[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToNFTItemMarketSpecs[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1;
                NFTItemMarketSpecs storage currentItem = idToNFTItemMarketSpecs[
                    currentId
                ];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
}
