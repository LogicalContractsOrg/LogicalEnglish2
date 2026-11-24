// SPDX-License-Identifier: MIT
// A small collateral vault that reads a price feed: the E12 worked example.
// Deposits are translated; the withdrawal, which calls the feed (an external
// contract), is left as residue — and filled by the E12 convention in
// lps2/examples/migration/solidity/oracle/.
pragma solidity ^0.8.20;

interface IPriceFeed {
    function latestPrice() external view returns (uint256);
}

contract Vault {
    IPriceFeed public feed;
    mapping(address account => uint256) public collateral;
    mapping(address account => uint256) public debt;

    error Undercollateralised(address account);

    constructor(IPriceFeed feed_) { feed = feed_; }

    function deposit(uint256 amount) external {
        collateral[msg.sender] += amount;
    }

    function borrow(uint256 amount) external {
        uint256 price = feed.latestPrice();
        if (collateral[msg.sender] * price < 2 * (debt[msg.sender] + amount)) {
            revert Undercollateralised(msg.sender);
        }
        debt[msg.sender] += amount;
    }
}
