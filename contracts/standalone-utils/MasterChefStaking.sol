// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../solidity-utils/openzeppelin/Address.sol";
import "../interfaces/solidity-utils/openzeppelin/IERC20.sol";

import "../interfaces/vault/IVault.sol";

import "./IBaseRelayerLibrary.sol";
import "./IMasterChef.sol";

/**
 * @title MasterChefStaking
 * @notice Allows users to deposit and withdraw BPT to/from a MasterChef contract
 * @dev All functions must be payable so that it can be called as part of a multicall involving ETH
 */
abstract contract MasterChefStaking is IBaseRelayerLibrary {
    using Address for address payable;

    IMasterChef private immutable _masterChef;

    constructor(IMasterChef masterChef) {
        _masterChef = masterChef;
    }

    function masterChefDeposit(
        address sender,
        address recipient,
        IERC20 token,
        uint256 pid,
        uint256 amount,
        uint256 outputReference
    ) external payable {
        require(address(_masterChef.lpTokens(pid)) == address(token), "Incorrect token for pid");

        if (_isChainedReference(amount)) {
            amount = _getChainedReferenceValue(amount);
        }

        // The deposit caller is the implicit sender of tokens, so if the goal is for the tokens
        // to be sourced from outside the relayer, we must first pull them here.
        if (sender != address(this)) {
            require(sender == msg.sender, "Incorrect sender");
            _pullToken(sender, token, amount);
        }

        // deposit the tokens to the masterchef
        token.approve(address(_masterChef), amount);
        _masterChef.deposit(pid, amount, recipient);

        if (_isChainedReference(outputReference)) {
            _setChainedReferenceValue(outputReference, amount);
        }
    }

    function masterChefWithdraw(
        address recipient,
        uint256 pid,
        uint256 amount,
        uint256 outputReference
    ) external payable {
        if (_isChainedReference(amount)) {
            amount = _getChainedReferenceValue(amount);
        }

        // withdraw the token from the masterchef, sending it to the recipient
        _masterChef.withdrawAndHarvest(pid, amount, recipient);

        if (_isChainedReference(outputReference)) {
            _setChainedReferenceValue(outputReference, amount);
        }
    }
}
