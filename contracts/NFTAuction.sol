//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import "./NFTMarketplace.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTAuction {
    NFTMarketplace marketplace;
    address marketplaceAddress;
    address NFTMarketplaceOwner;
    mapping(uint256 => Auction) public IdtoAuction; // tokenid to auction
    mapping(uint256 => mapping(address => uint256)) public bids; // tokenid to bids of addresses
    uint256 listingFee = 0.01 ether;

    // need to get some details from imported nftmarketplace contract
    struct Auction {
        // address marketplaceAddress;
        uint nftId;
        address payable seller;
        uint minPrice;
        uint endAt;
        bool started;
        bool ended;
        address highestBidder;
        uint highestBid;
        address creator;
        uint royaltPercent;
    }

    constructor(address _marketplaceAddress, address _marketplaceOwner) {
        marketplace = NFTMarketplace(_marketplaceAddress);
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

    // TODO
    // for starting auction the seller should pay some listing commision.

    function start(
        uint nftId,
        uint _minPrice,
        uint8 auctiondays
    ) external payable {
        require(!IdtoAuction[nftId].started, "Started");
        require(
            msg.sender == IERC721(marketplaceAddress).ownerOf(nftId),
            "Started"
        );
        require(msg.value == listingFee, "Must be equal to listing price");
        require(
            auctiondays <= 7 && auctiondays >= 1,
            "auction time should be less than 7 days and more than 1 day"
        );
        // the seller should approve this contract to execute the below code
        // the approval function can be put in front-end

        IdtoAuction[nftId].started = true;
        IdtoAuction[nftId].nftId = nftId;
        IdtoAuction[nftId].seller = payable(msg.sender);
        IdtoAuction[nftId].minPrice = _minPrice;
        IdtoAuction[nftId].endAt = block.timestamp + auctiondays;

        IdtoAuction[nftId].creator = marketplace.fetchCreatorNft(nftId);

        IdtoAuction[nftId].royaltPercent = marketplace.fetchRoyaltyPercentofNft(
            nftId
        );

        IERC721(marketplaceAddress).transferFrom(
            msg.sender,
            address(this),
            nftId
        );

        // emit start();
    }

    function updatelistingFee(uint256 _listingFee) external onlyOwner {
        listingFee = _listingFee;

        // emit ListingChargeUpdated();
    }

    function withdrawCommission() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Zero balance in the account.");
        payable(NFTMarketplaceOwner).transfer(address(this).balance);

        // emit MarketplaceBalanceWithdrew();
    }

    function bid(uint nftId) external payable {
        require(IdtoAuction[nftId].started, "Not Started");
        require(block.timestamp < IdtoAuction[nftId].endAt, "ended");
        require(
            msg.value > IdtoAuction[nftId].highestBid, /*msg.value + IdtoAuction[nftId].bids[msg.sender]*/
            "value should be greater than current highest bid"
        );

        if (IdtoAuction[nftId].highestBidder != address(0)) {
            bids[nftId][IdtoAuction[nftId].highestBidder] += IdtoAuction[nftId]
                .highestBid; /*+=msg.value*/
        }

        IdtoAuction[nftId].highestBidder = msg.sender;
        IdtoAuction[nftId].highestBid = msg.value; /*msg.value + IdtoAuction[nftId].bids[msg.sender]*/

        // emit Bid();
    }

    function withdraw(uint nftId) external {
        require(block.timestamp > IdtoAuction[nftId].endAt);
        uint bal = bids[nftId][msg.sender];
        bids[nftId][msg.sender] = 0;
        payable(msg.sender).transfer(bal);
        // emit Withdraw();
    }

    function end(uint nftId) external {
        require(IdtoAuction[nftId].started, "not started");
        require(block.timestamp > IdtoAuction[nftId].endAt);
        require(!IdtoAuction[nftId].ended, "ended");
        IdtoAuction[nftId].ended = true;

        // need to send nft to the buyer, need to transfer royalty to creator
    }

    function fetchNftAuctionData(uint nftId)
        public
        view
        returns (Auction memory)
    {
        return IdtoAuction[nftId];
    }

    function fetchMyBidAmountDataForNft(uint nftId) public view returns (uint) {
        return bids[nftId][msg.sender];
    }
}
