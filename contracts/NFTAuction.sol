//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface INFTMarketplace {
    function fetchCreatorNft(uint tokenId) external view returns (address);

    function fetchRoyaltyPercentofNft(
        uint tokenId
    ) external view returns (uint);

    function listingFee() external view returns (uint256);

    function serviceFeePercent() external view returns (uint256);
}

contract NFTAuction {
    INFTMarketplace marketplace;
    address marketplaceAddress;
    address payable NFTMarketplaceOwner;
    mapping(uint256 => Auction) public IdtoAuction; // tokenid to auction

    uint public listingfeeAccruel;

    // need to get some details from imported nftmarketplace contract
    struct Auction {
        // address marketplaceAddress;
        uint nftId;
        address seller;
        uint minPrice;
        uint endAt;
        bool started;
        bool ended;
        address highestBidder;
        uint highestBid;
        address creator;
        uint royaltyPercent;
    }

    event auctionStarted(
        uint indexed nftId,
        uint indexed minPrice,
        uint indexed auctiondays,
        uint listingfee
    );
    event biddingPlaced(
        uint indexed nftId,
        address indexed highestBidder,
        uint indexed highestBid,
        uint endAt
    );

    event commissionWithdrawn(uint commission);

    event auctionEnded(string indexed ended, address indexed nftReceiver);

    constructor(address _marketplaceAddress, address _marketplaceOwner) {
        marketplace = INFTMarketplace(_marketplaceAddress);
        marketplaceAddress = _marketplaceAddress;
        NFTMarketplaceOwner = payable(_marketplaceOwner);
    }

    modifier onlyOwner() {
        require(
            msg.sender == NFTMarketplaceOwner,
            "only owner of the marketplace can perform this action"
        );
        _;
    }

    function start(
        uint nftId,
        uint _minPrice,
        uint8 auctiondays
    ) external payable {
        require(
            !IdtoAuction[nftId].started,
            "Only owner of nft can list the nft in auction or its already in auction"
        );
        require(
            msg.sender == IERC721(marketplaceAddress).ownerOf(nftId),
            "Only owner of nft can list the nft in auction or its already in auction"
        );
        require(
            msg.value == marketplace.listingFee(),
            "Must be equal to listing price"
        );
        require(
            auctiondays <= 7 && auctiondays >= 1,
            "auction time should be less than 7 days and more than 1 day"
        );
        // the seller should approve this contract to execute the below code
        // the approval function can be put in front-end

        IdtoAuction[nftId].started = true;
        IdtoAuction[nftId].ended = false;
        IdtoAuction[nftId].nftId = nftId;
        IdtoAuction[nftId].seller = msg.sender;
        IdtoAuction[nftId].minPrice = _minPrice;
        IdtoAuction[nftId].endAt = block.timestamp + auctiondays * 1 days;
        listingfeeAccruel += msg.value;

        IdtoAuction[nftId].creator = marketplace.fetchCreatorNft(nftId);

        IdtoAuction[nftId].royaltyPercent = marketplace
            .fetchRoyaltyPercentofNft(nftId);

        IERC721(marketplaceAddress).transferFrom(
            msg.sender,
            address(this),
            nftId
        );

        emit auctionStarted(
            nftId,
            IdtoAuction[nftId].minPrice,
            auctiondays,
            msg.value
        );
    }

    function withdrawListingFeeCommission() external onlyOwner {
        require(listingfeeAccruel > 0, "Zero balance in the account.");
        uint feeAccruel = listingfeeAccruel;
        listingfeeAccruel = 0;
        NFTMarketplaceOwner.transfer(feeAccruel);
        emit commissionWithdrawn(feeAccruel);
    }

    function bid(uint nftId) external payable {
        require(
            IdtoAuction[nftId].started,
            "There is no ongoing auction for this nft"
        );
        require(block.timestamp < IdtoAuction[nftId].endAt, "auction expired");
        require(
            msg.value > IdtoAuction[nftId].highestBid,
            "value should be greater than current highest bid"
        );
        require(
            msg.value > IdtoAuction[nftId].minPrice,
            "value should be greater minprice"
        );
        require(
            msg.sender != IdtoAuction[nftId].seller &&
                msg.sender != NFTMarketplaceOwner,
            "seller and marketplace owner cannot participate in the bidding"
        );

        address prevHighestBidder;
        uint prevHighestBid;

        if (IdtoAuction[nftId].highestBidder != address(0)) {
            prevHighestBidder = IdtoAuction[nftId].highestBidder;
            prevHighestBid = IdtoAuction[nftId].highestBid;
        }

        IdtoAuction[nftId].highestBidder = msg.sender;
        IdtoAuction[nftId].highestBid = msg.value;

        if (IdtoAuction[nftId].highestBidder != address(0)) {
            payable(prevHighestBidder).transfer(prevHighestBid);
        }

        if (
            block.timestamp < IdtoAuction[nftId].endAt &&
            block.timestamp > IdtoAuction[nftId].endAt - 600
        ) {
            IdtoAuction[nftId].endAt += 600;
        }

        emit biddingPlaced(
            nftId,
            IdtoAuction[nftId].highestBidder,
            IdtoAuction[nftId].highestBid,
            IdtoAuction[nftId].endAt
        );
    }

    function end(uint nftId) external {
        require(
            IdtoAuction[nftId].started,
            "There is no ongoing auction for this nft"
        );
        require(
            block.timestamp > IdtoAuction[nftId].endAt,
            "auction still ongoing"
        );
        require(!IdtoAuction[nftId].ended, "auction ended");
        IdtoAuction[nftId].ended = true;

        uint256 royaltyAmount = ((IdtoAuction[nftId].royaltyPercent *
            IdtoAuction[nftId].highestBid) / 100);

        uint ServiceFeePercent = marketplace.serviceFeePercent();

        uint MarketplaceOwnerServiceFee = ((ServiceFeePercent *
            IdtoAuction[nftId].highestBid) / 100);

        uint256 SellerPayout = IdtoAuction[nftId].highestBid -
            (MarketplaceOwnerServiceFee + royaltyAmount);

        address seller = IdtoAuction[nftId].seller;

        IdtoAuction[nftId].started = false;
        IdtoAuction[nftId].minPrice = 0;

        if (IdtoAuction[nftId].highestBidder != address(0)) {
            IERC721(marketplaceAddress).safeTransferFrom(
                address(this),
                IdtoAuction[nftId].highestBidder,
                nftId
            );
            IdtoAuction[nftId].highestBid = 0;
            IdtoAuction[nftId].highestBidder = address(0);
            IdtoAuction[nftId].seller = address(0);

            payable(seller).transfer(SellerPayout);

            payable(IdtoAuction[nftId].creator).transfer(royaltyAmount);

            NFTMarketplaceOwner.transfer(MarketplaceOwnerServiceFee);
            emit auctionEnded(
                "auction ended with sale",
                IdtoAuction[nftId].highestBidder
            );
        } else {
            IERC721(marketplaceAddress).safeTransferFrom(
                address(this),
                IdtoAuction[nftId].seller,
                nftId
            );
            IdtoAuction[nftId].highestBidder = address(0);
            IdtoAuction[nftId].highestBid = 0;
            IdtoAuction[nftId].seller = address(0);

            emit auctionEnded("auction ended without sale", seller);
        }
    }

    function fetchNftAuctionData(
        uint nftId
    ) public view returns (Auction memory) {
        return IdtoAuction[nftId];
    }

    function fetchListingfee() public view returns (uint) {
        return marketplace.listingFee();
    }

    function fetchServiceFeePercent() public view returns (uint) {
        return marketplace.serviceFeePercent();
    }
}
