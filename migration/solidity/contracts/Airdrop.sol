// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// A token with batch calls: the loops over arrays of
/// the design notes roadmap.md, Phase 1e (d).
contract Airdrop {
    mapping(address => uint256) public balances;
    uint256 public totalSupply;

    constructor(address holder, uint256 supply) {
        balances[holder] = supply;
        totalSupply = supply;
    }

    /// The same amount to each recipient (a batch write): a recipient listed
    /// twice gets it twice.
    function airdrop(address[] calldata recipients, uint256 amount) external {
        require(balances[msg.sender] >= amount * recipients.length, "insufficient balance");
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "zero recipient");
            balances[recipients[i]] += amount;
        }
        balances[msg.sender] -= amount * recipients.length;
    }

    /// Burns the sum of a list of amounts (a reduction).
    function burnEach(uint256[] calldata amounts) external {
        uint256 total = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
        require(balances[msg.sender] >= total, "insufficient balance");
        balances[msg.sender] -= total;
        totalSupply -= total;
    }

    /// Pays the first candidate that holds nothing (a search with an early
    /// exit: what it does depends on the order, and stays residue).
    function payFirstEmpty(address[] calldata candidates, uint256 amount) external {
        for (uint256 i = 0; i < candidates.length; i++) {
            if (balances[candidates[i]] == 0) {
                balances[candidates[i]] += amount;
                balances[msg.sender] -= amount;
                break;
            }
        }
    }
}
