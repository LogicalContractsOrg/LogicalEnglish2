// SPDX-License-Identifier: MIT
// The Ownable reference model (E11): OpenZeppelin's Ownable on its own.
pragma solidity ^0.8.20;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RefOwnable is Ownable {
    constructor(address initialOwner) Ownable(initialOwner) {}
}
