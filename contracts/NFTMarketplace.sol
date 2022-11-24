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

    uint256 listingPrice = 0.025 ether;
    address payable NFTMarketplaceOwner;

    mapping(uint256 => NFTItemMarketSpecs) private idToNFTItemMarketSpecs;

    struct NFTItemMarketSpecs {
        uint256 tokenId;
        address payable creator;
        uint256 royaltyPercent;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }

    event ListingNFT(
        uint256 indexed tokenId,
        address creator,
        uint256 royaltyPercent,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    // event ListingCancelled(
    //     uint256 indexed tokenId,
    //     address creator,
    //     address seller,
    //     address owner
    // );

    modifier onlyOwner() {
        require(
            msg.sender == NFTMarketplaceOwner,
            "only owner of the marketplace can change the listing price"
        );
        _;
    }

    constructor() ERC721("BlockHole Tokens", "BHT") {
        NFTMarketplaceOwner = payable(msg.sender);
    }

    function updateListingPrice(uint256 _listingPrice)
        public
        payable
        onlyOwner
    {
        listingPrice = _listingPrice;
    }

    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    function createNFTAndList(
        string memory tokenURI,
        uint256 price,
        uint256 royaltyPercent
    ) public payable returns (uint256) {
        require(royaltyPercent <= 10, "Royalty should be less than 10%");
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, tokenURI);
        SellNftByCreator(tokenId, price, royaltyPercent);
        return tokenId;
    }

    function SellNftByCreator(
        uint256 tokenId,
        uint256 price,
        uint256 royaltyPercent
    ) private {
        require(price > 0, "Price cannot be 0");
        require(msg.value == listingPrice, "Must be equal to listing price");

        idToNFTItemMarketSpecs[tokenId] = NFTItemMarketSpecs(
            tokenId, // tokenId
            payable(msg.sender), // creator
            royaltyPercent, // royalty percent
            payable(msg.sender), // seller
            payable(address(this)), // owner (seller transfers the nft to contract for sale. so contract is the current owner)
            price, // price
            false // sell status
        );

        _transfer(msg.sender, address(this), tokenId);

        emit ListingNFT(
            tokenId,
            msg.sender,
            royaltyPercent,
            msg.sender,
            address(this),
            price,
            false
        );
    }

    // function changeRoyaltyPercentByCreator() external {}

    function resellNft(uint256 tokenId, uint256 price) public payable {
        require(
            idToNFTItemMarketSpecs[tokenId].owner == msg.sender,
            "Only the owner of nft can sell his nft"
        );
        require(msg.value == listingPrice, "Must be equal to listing price");
        idToNFTItemMarketSpecs[tokenId].sold = false;
        idToNFTItemMarketSpecs[tokenId].price = price;
        idToNFTItemMarketSpecs[tokenId].seller = payable(msg.sender);
        idToNFTItemMarketSpecs[tokenId].owner = payable(address(this));
        _itemsSold.decrement();

        _transfer(msg.sender, address(this), tokenId);
    }

    function cancelListing(uint256 tokenId) external {
        address seller = idToNFTItemMarketSpecs[tokenId].seller;
        require(
            idToNFTItemMarketSpecs[tokenId].seller == msg.sender,
            "Only the seller can cancel the listing"
        );
        idToNFTItemMarketSpecs[tokenId].owner = payable(msg.sender);
        idToNFTItemMarketSpecs[tokenId].seller = payable(address(0));

        _transfer(address(this), seller, tokenId);

        emit ListingCancelled(
            tokenId,
            idToNFTItemMarketSpecs[tokenId].owner,
            msg.sender,
            msg.sender
        );
    }

    function buyNFT(uint256 tokenId) public payable {
        uint256 price = idToNFTItemMarketSpecs[tokenId].price;
        uint256 royaltyAmount = ((idToNFTItemMarketSpecs[tokenId]
            .royaltyPercent * msg.value) / 100);
        uint256 SellerPayout = price - royaltyAmount;
        require(msg.value >= price, "value is not equal to nft purchase price");
        idToNFTItemMarketSpecs[tokenId].owner = payable(msg.sender);
        idToNFTItemMarketSpecs[tokenId].sold = true;
        idToNFTItemMarketSpecs[tokenId].seller = payable(address(0));
        _itemsSold.increment();
        _transfer(address(this), msg.sender, tokenId);
        payable(idToNFTItemMarketSpecs[tokenId].creator).transfer(
            royaltyAmount
        );
        payable(idToNFTItemMarketSpecs[tokenId].seller).transfer(SellerPayout);
    }

    function withdrawListingCommission() public {
        require(
            msg.sender == NFTMarketplaceOwner,
            "Only the owner can withdraw the listing commission"
        );
        payable(NFTMarketplaceOwner).transfer(address(this).balance);
    }

    function fetchAllNFTs() public view returns (NFTItemMarketSpecs[] memory) {
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

    function fetchListedNFTs()
        public
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