// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

contract DistributionPool is Ownable, AccessControl {
    mapping(address => uint256) public balances;
    address tokenDistribution;

    bytes32 public constant managerRole = keccak256("MANAGER_ROLE");

    event ClaimToken(address indexed user, uint256 amount);
    event BalanceUpdated(address indexed user, uint256 amount);

    constructor(
        address initialOwner,
        address _tokenDistribution
    ) Ownable(initialOwner) {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        tokenDistribution = _tokenDistribution;
    }

    // claim token
    function claimToken(uint256 _amount) public {
        require(
            balances[msg.sender] >= _amount,
            "Insufficient balance for user"
        );
        balances[msg.sender] -= _amount;
        TransferHelper.safeTransfer(tokenDistribution, msg.sender, _amount);
        emit ClaimToken(msg.sender, _amount);
    }

    // update batch balances only manager
    function updateBatchBalances(
        bytes calldata _addresses,
        bytes calldata _amounts
    ) public onlyRole(managerRole) {
        address[] memory addresses = abi.decode(_addresses, (address[]));
        uint256[] memory amounts = abi.decode(_amounts, (uint256[]));
        require(
            addresses.length == amounts.length,
            "Addresses and amounts length mismatch"
        );
        for (uint256 index = 0; index < addresses.length; index++) {
            _updateBalances(addresses[index], amounts[index]);
        }
    }

    // update balances for internal user
    function _updateBalances(address _userAddress, uint256 _amount) internal {
        balances[_userAddress] = _amount;
        emit BalanceUpdated(_userAddress, _amount);
    }

    function transferOwnership(
        address newOwner
    ) public virtual override onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _grantRole(DEFAULT_ADMIN_ROLE, newOwner);
        _transferOwnership(newOwner);
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // add role manager
    function addManager(address manager) public onlyOwner {
        _grantRole(managerRole, manager);
    }

    // remove role manager
    function removeManager(address manager) public onlyOwner {
        _revokeRole(managerRole, manager);
    }

    // withdraw funds only owner when emergency
    function withdrawFunds(
        address _to,
        address _token,
        uint256 _amount
    ) public onlyOwner {
        if (_token == address(0)) {
            payable(_to).transfer(_amount);
        } else {
            TransferHelper.safeTransfer(_token, _to, _amount);
        }
    }
}
