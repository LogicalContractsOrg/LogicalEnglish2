// SPDX-License-Identifier: MIT
// The Pausable reference model (E11): OpenZeppelin's Pausable, its pause and
// unpause exposed to the owner (the usual composition).
pragma solidity ^0.8.20;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract RefPausable is Ownable, Pausable {
    constructor(address initialOwner) Ownable(initialOwner) {}
    function pause() public onlyOwner { _pause(); }
    function unpause() public onlyOwner { _unpause(); }
}
