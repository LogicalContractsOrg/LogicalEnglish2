// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract MyToken is ERC20, Ownable, Pausable {
    constructor(address initialOwner) ERC20("MyToken", "MTK") Ownable(initialOwner) {}
    function pause() public onlyOwner { _pause(); }
    function unpause() public onlyOwner { _unpause(); }
    function mint(address to, uint256 amount) public onlyOwner { _mint(to, amount); }
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        super._update(from, to, value);
    }
}
