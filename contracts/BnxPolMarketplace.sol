// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTMarketplace is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 public listingFee = 0.01 ether;
    address payable NFTMarketplaceOwner;
    address Bnxtoken;

    mapping(uint256 => NFTItemMarketSpecs) idToNFTItemMarketSpecs;

    struct NFTItemMarketSpecs {
        uint256 tokenId;
        address creator;
        uint256 royaltyPercent;
        address seller;
        address owner;
        uint256 priceinMATIC;
        uint256 priceinBnx;
        bool isMatic;
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
        string mode
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
        address indexed owner,
        string mode
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
        ERC721("Blockhole Tokens", "BHT")
    {
        NFTMarketplaceOwner = payable(_marketplaceOwner);
        Bnxtoken = _token;
    }

    function updatelistingFee(uint256 _listingFee) external onlyOwner {
        listingFee = _listingFee;

        emit ListingChargeUpdated("Listing Charge Updated", listingFee);
    }

    function createNFT(string memory tokenUri, uint256 royaltyPercent)
        external
    {
        require(
            royaltyPercent <= 10,
            "Royalty should be equal to or less than 10%"
        );
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

    function listNFT(
        uint256 tokenId,
        uint256 price,
        bool _isMatic
    ) external payable {
        string memory mode;
        require(price > 0, "Price cannot be 0");
        require(msg.value == listingFee, "Must be equal to listing price");
        require(
            IERC721(address(this)).ownerOf(tokenId) == msg.sender,
            "Only the owner of nft can list the nft for sale"
        );

        idToNFTItemMarketSpecs[tokenId].seller = msg.sender;
        idToNFTItemMarketSpecs[tokenId].owner = address(this);
        if (_isMatic) {
            mode = "MATIC";
            idToNFTItemMarketSpecs[tokenId].isMatic = true;
            idToNFTItemMarketSpecs[tokenId].priceinMATIC = price;
        } else {
            mode = "BNX";
            idToNFTItemMarketSpecs[tokenId].isMatic = false;
            idToNFTItemMarketSpecs[tokenId].priceinBnx = price;
        }
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
            mode
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
        idToNFTItemMarketSpecs[tokenId].priceinMATIC = 0;
        idToNFTItemMarketSpecs[tokenId].priceinBnx = 0;
        idToNFTItemMarketSpecs[tokenId].isMatic = false;

        _transfer(address(this), seller, tokenId);

        emit ListingCancelled(
            tokenId,
            idToNFTItemMarketSpecs[tokenId].creator,
            msg.sender,
            msg.sender
        );
    }

    function buyNFT(uint256 tokenId) external payable {
        uint256 price;
        string memory mode;
        if (idToNFTItemMarketSpecs[tokenId].isMatic) {
            mode = "MATIC";
            price = idToNFTItemMarketSpecs[tokenId].priceinMATIC;
            require(
                msg.value == price,
                "value is not equal to nft purchase price"
            );
        } else {
            mode = "BNX";
            price = idToNFTItemMarketSpecs[tokenId].priceinBnx;
        }

        address seller = idToNFTItemMarketSpecs[tokenId].seller;
        uint256 royaltyAmount = ((idToNFTItemMarketSpecs[tokenId]
            .royaltyPercent * price) / 100);
        uint256 SellerPayout = price - royaltyAmount;
        idToNFTItemMarketSpecs[tokenId].owner = msg.sender;
        idToNFTItemMarketSpecs[tokenId].sold = true;
        idToNFTItemMarketSpecs[tokenId].seller = address(0);
        idToNFTItemMarketSpecs[tokenId].priceinMATIC = 0;
        idToNFTItemMarketSpecs[tokenId].priceinBnx = 0;

        _transfer(address(this), msg.sender, tokenId);

        if (idToNFTItemMarketSpecs[tokenId].isMatic) {
            idToNFTItemMarketSpecs[tokenId].isMatic = false;
            payable(idToNFTItemMarketSpecs[tokenId].creator).transfer(
                royaltyAmount
            );
            payable(seller).transfer(SellerPayout);
        } else {
            // approval need to be done before this can be done
            IERC20(Bnxtoken).transferFrom(msg.sender, address(this), price);
            IERC20(Bnxtoken).transfer(seller, SellerPayout);
            IERC20(Bnxtoken).transfer(
                idToNFTItemMarketSpecs[tokenId].creator,
                royaltyAmount
            );
        }

        emit buyingNFT(
            tokenId,
            idToNFTItemMarketSpecs[tokenId].creator,
            seller,
            msg.sender,
            mode
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

    function contractBalance() external view returns (uint) {
        return address(this).balance;
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
            idToNFTItemMarketSpecs[tokenId].priceinMATIC,
            idToNFTItemMarketSpecs[tokenId].priceinBnx,
            idToNFTItemMarketSpecs[tokenId].isMatic,
            idToNFTItemMarketSpecs[tokenId].sold
        );

        return NFTDetails;
    }
}
