// SPDX-License-Identifier: MIT
// The ERC-20 reference model (E11): OpenZeppelin's ERC20 with an initial
// supply minted to a holder, the shape of most deployed OpenZeppelin tokens.
pragma solidity ^0.8.20;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RefERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_, address holder, uint256 supply)
        ERC20(name_, symbol_)
    {
        _mint(holder, supply);
    }
}
