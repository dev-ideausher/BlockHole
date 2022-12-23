//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import "./NFTMarketplace.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTAuction {
    NFTMarketplace marketplace;
    mapping(uint256 => Auction) public IdtoAuction; // tokenid to auction
    // need to get some details from nftmarketplace contract
    struct Auction {
        address nftId;
        address seller;
        address creator;
        address royalty;
    }

    constructor(address marketplaceAddress) {
        marketplace = NFTMarketplace(marketplaceAddress);
    }
}
