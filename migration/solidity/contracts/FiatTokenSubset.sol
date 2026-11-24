// SPDX-License-Identifier: Apache-2.0 AND MIT
//
// FiatTokenSubset: a changed copy of a part of Circle's stablecoin-evm
// (https://github.com/circlefin/stablecoin-evm, contracts/v1/). It is not
// Circle's contract, and Circle did not review it. It was written in
// September 2026 as a test contract for the Logical English translator of
// Solidity.
//
// The files it was transcribed from, each with the notice it carries there:
//
// 1. FiatTokenV1.sol and Blacklistable.sol (the parts marked "FiatTokenV1"
//    and "Blacklistable" below), under the Apache License 2.0:
//
//     Copyright 2023 Circle Internet Group, Inc. All rights reserved.
//
//     Licensed under the Apache License, Version 2.0 (the "License");
//     you may not use this file except in compliance with the License.
//     You may obtain a copy of the License at
//
//         http://www.apache.org/licenses/LICENSE-2.0
//
//     Unless required by applicable law or agreed to in writing, software
//     distributed under the License is distributed on an "AS IS" BASIS,
//     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//     See the License for the specific language governing permissions and
//     limitations under the License.
//
// 2. Ownable.sol and Pausable.sol (the parts marked "Ownable" and "Pausable"
//    below), which Circle forked from OpenZeppelin, under the MIT licence.
//    Ownable.sol:
//
//     Copyright (c) 2018 zOS Global Limited.
//     Copyright (c) 2018-2020 CENTRE SECZ
//
//    Pausable.sol:
//
//     Copyright (c) 2016 Smart Contract Solutions, Inc.
//     Copyright (c) 2018-2020 CENTRE SECZ
//
//    Both, after those lines:
//
//     Permission is hereby granted, free of charge, to any person obtaining a copy
//     of this software and associated documentation files (the "Software"), to deal
//     in the Software without restriction, including without limitation the rights
//     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//     copies of the Software, and to permit persons to whom the Software is
//     furnished to do so, subject to the following conditions:
//
//     The above copyright notice and this permission notice shall be included in
//     copies or substantial portions of the Software.
//
//     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//     SOFTWARE.
//
// The changes. The code is in Solidity 0.8 (Circle's is 0.6.12), in one
// contract. SafeMath's add/sub become checked arithmetic (both revert on
// overflow). balanceAndBlacklistStates is a plain balance mapping and
// _deprecatedBlacklisted the blacklist, and the internal helpers (setOwner,
// _setBalance, _balanceOf, _blacklist, _unBlacklist, _isBlacklisted) are
// written in place. `initialize` is the constructor, without the name, the
// symbol, the currency and the decimals of the token. Left out: the proxy,
// EIP-2612/3009 (V2), the rescue functions, the views owner, allowance,
// minterAllowance, isMinter and isBlacklisted, and the events PauserChanged,
// BlacklisterChanged and MasterMinterChanged. The require messages are those
// of Circle's files.
pragma solidity ^0.8.20;

contract FiatTokenSubset {
    // --- Ownable (Circle's fork of OpenZeppelin's; MIT)
    address private _owner;
    event OwnershipTransferred(address previousOwner, address newOwner);

    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    // --- Pausable (Circle's fork of OpenZeppelin's; MIT)
    event Pause();
    event Unpause();
    address public pauser;
    bool public paused = false;

    modifier whenNotPaused() {
        require(!paused, "Pausable: paused");
        _;
    }

    modifier onlyPauser() {
        require(msg.sender == pauser, "Pausable: caller is not the pauser");
        _;
    }

    function pause() external onlyPauser {
        paused = true;
        emit Pause();
    }

    function unpause() external onlyPauser {
        paused = false;
        emit Unpause();
    }

    function updatePauser(address _newPauser) external onlyOwner {
        require(_newPauser != address(0), "Pausable: new pauser is the zero address");
        pauser = _newPauser;
    }

    // --- Blacklistable (Circle; Apache-2.0)
    address public blacklister;
    mapping(address account => bool) internal blacklisted;
    event Blacklisted(address indexed _account);
    event UnBlacklisted(address indexed _account);

    modifier onlyBlacklister() {
        require(msg.sender == blacklister, "Blacklistable: caller is not the blacklister");
        _;
    }

    modifier notBlacklisted(address _account) {
        require(!blacklisted[_account], "Blacklistable: account is blacklisted");
        _;
    }

    function blacklist(address _account) external onlyBlacklister {
        blacklisted[_account] = true;
        emit Blacklisted(_account);
    }

    function unBlacklist(address _account) external onlyBlacklister {
        blacklisted[_account] = false;
        emit UnBlacklisted(_account);
    }

    function updateBlacklister(address _newBlacklister) external onlyOwner {
        require(_newBlacklister != address(0), "Blacklistable: new blacklister is the zero address");
        blacklister = _newBlacklister;
    }

    // --- FiatTokenV1 (Circle; Apache-2.0)
    address public masterMinter;
    mapping(address account => uint256) internal balances;
    mapping(address owner => mapping(address spender => uint256)) internal allowed;
    uint256 internal totalSupply_ = 0;
    mapping(address minter => bool) internal minters;
    mapping(address minter => uint256) internal minterAllowed;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed minter, address indexed to, uint256 amount);
    event Burn(address indexed burner, uint256 amount);
    event MinterConfigured(address indexed minter, uint256 minterAllowedAmount);
    event MinterRemoved(address indexed oldMinter);

    constructor(address newMasterMinter, address newPauser, address newBlacklister, address newOwner) {
        require(newMasterMinter != address(0), "FiatToken: new masterMinter is the zero address");
        require(newPauser != address(0), "FiatToken: new pauser is the zero address");
        require(newBlacklister != address(0), "FiatToken: new blacklister is the zero address");
        require(newOwner != address(0), "FiatToken: new owner is the zero address");
        masterMinter = newMasterMinter;
        pauser = newPauser;
        blacklister = newBlacklister;
        _owner = newOwner;
    }

    modifier onlyMinters() {
        require(minters[msg.sender], "FiatToken: caller is not a minter");
        _;
    }

    modifier onlyMasterMinter() {
        require(msg.sender == masterMinter, "FiatToken: caller is not the masterMinter");
        _;
    }

    function mint(address _to, uint256 _amount)
        external whenNotPaused onlyMinters notBlacklisted(msg.sender) notBlacklisted(_to) returns (bool)
    {
        require(_to != address(0), "FiatToken: mint to the zero address");
        require(_amount > 0, "FiatToken: mint amount not greater than 0");
        uint256 mintingAllowedAmount = minterAllowed[msg.sender];
        require(_amount <= mintingAllowedAmount, "FiatToken: mint amount exceeds minterAllowance");
        totalSupply_ = totalSupply_ + _amount;
        balances[_to] = balances[_to] + _amount;
        minterAllowed[msg.sender] = mintingAllowedAmount - _amount;
        emit Mint(msg.sender, _to, _amount);
        emit Transfer(address(0), _to, _amount);
        return true;
    }

    function approve(address spender, uint256 value)
        external whenNotPaused notBlacklisted(msg.sender) notBlacklisted(spender) returns (bool)
    {
        _approve(msg.sender, spender, value);
        return true;
    }

    function _approve(address owner, address spender, uint256 value) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        allowed[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function transferFrom(address from, address to, uint256 value)
        external whenNotPaused notBlacklisted(msg.sender) notBlacklisted(from) notBlacklisted(to) returns (bool)
    {
        require(value <= allowed[from][msg.sender], "ERC20: transfer amount exceeds allowance");
        _transfer(from, to, value);
        allowed[from][msg.sender] = allowed[from][msg.sender] - value;
        return true;
    }

    function transfer(address to, uint256 value)
        external whenNotPaused notBlacklisted(msg.sender) notBlacklisted(to) returns (bool)
    {
        _transfer(msg.sender, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(value <= balances[from], "ERC20: transfer amount exceeds balance");
        balances[from] = balances[from] - value;
        balances[to] = balances[to] + value;
        emit Transfer(from, to, value);
    }

    function configureMinter(address minter, uint256 minterAllowedAmount)
        external whenNotPaused onlyMasterMinter returns (bool)
    {
        minters[minter] = true;
        minterAllowed[minter] = minterAllowedAmount;
        emit MinterConfigured(minter, minterAllowedAmount);
        return true;
    }

    function removeMinter(address minter) external onlyMasterMinter returns (bool) {
        minters[minter] = false;
        minterAllowed[minter] = 0;
        emit MinterRemoved(minter);
        return true;
    }

    function burn(uint256 _amount) external whenNotPaused onlyMinters notBlacklisted(msg.sender) {
        uint256 balance = balances[msg.sender];
        require(_amount > 0, "FiatToken: burn amount not greater than 0");
        require(balance >= _amount, "FiatToken: burn amount exceeds balance");
        totalSupply_ = totalSupply_ - _amount;
        balances[msg.sender] = balance - _amount;
        emit Burn(msg.sender, _amount);
        emit Transfer(msg.sender, address(0), _amount);
    }

    function updateMasterMinter(address _newMasterMinter) external onlyOwner {
        require(_newMasterMinter != address(0), "FiatToken: new masterMinter is the zero address");
        masterMinter = _newMasterMinter;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function totalSupply() external view returns (uint256) {
        return totalSupply_;
    }
}
