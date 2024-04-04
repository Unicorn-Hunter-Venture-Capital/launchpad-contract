// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

contract PreparePool is Ownable, AccessControl {
    struct Pool {
        string id;
        string name;
        bool isRefundable;
        uint256 price;
        address tokenPayment;
        uint256 startDate;
        uint256 endDate;
    }
    struct Allocation {
        address userAddress;
        uint256 amount;
    }

    address public immutable passport; // check
    Pool public poolDetails;
    // storage allocation for users in the pool
    mapping(address => Allocation) public allocations;
    // storage for user deposits
    mapping(address => uint256) public deposited;
    // role manager
    bytes32 public constant managerRole = keccak256("MANAGER_ROLE");
    // total deposited funds
    uint256 public totalDeposited;

    event DepositFunds(address indexed user, uint256 amount);
    event PoolUpdated(string id, string name);
    event Refund(address indexed user, uint256 amount);
    event WithdrawFunds(address indexed user, uint256 amount, address token);

    constructor(address initialOwner, address _passport) Ownable(initialOwner) {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        passport = _passport;
    }

    // deposit funds
    function depositFunds(uint256 _amount) public {
        // check allocation for user
        require(
            allocations[msg.sender].amount >= _amount,
            "Insufficient allocation"
        );
        require(
            block.timestamp >= poolDetails.startDate &&
                block.timestamp <= poolDetails.endDate,
            "Pool not started or ended"
        );
        require(
            IERC721(passport).balanceOf(msg.sender) > 0,
            "User does not have passport"
        );

        // transfer funds from user to contract
        TransferHelper.safeTransferFrom(
            poolDetails.tokenPayment,
            msg.sender,
            address(this),
            _amount
        );
        // update funds and deduct allocation
        deposited[msg.sender] += _amount;
        allocations[msg.sender].amount -= _amount;
        totalDeposited += _amount;
        emit DepositFunds(msg.sender, _amount);
    }

    // update pool details
    function updatePoolDetails(
        string memory _id,
        string memory _name,
        uint256 _price,
        address _tokenPayment,
        uint256 _startDate,
        uint256 _endDate
    ) public onlyOwner {
        require(_startDate < _endDate, "Invalid start and end date");
        require(poolDetails.tokenPayment == address(0), "Pool already created");
        poolDetails = Pool({
            id: _id,
            name: _name,
            isRefundable: false,
            price: _price,
            tokenPayment: _tokenPayment,
            startDate: _startDate,
            endDate: _endDate
        });

        emit PoolUpdated(_id, _name);
    }

    // set refundable
    function setRefundable(bool _isRefundable) public onlyRole(managerRole) {
        poolDetails.isRefundable = _isRefundable;
    }

    // refund user funds if pool is refundable and remove allocation
    function refund() public {
        require(poolDetails.isRefundable, "Pool not refundable");

        uint256 depositedUser = deposited[msg.sender];
        require(depositedUser > 0, "No funds deposited");

        // transfer funds to user
        TransferHelper.safeTransfer(
            poolDetails.tokenPayment,
            msg.sender,
            depositedUser
        );

        // remove allocation and update total deposited
        allocations[msg.sender].amount = 0;
        deposited[msg.sender] = 0;
        totalDeposited -= depositedUser;
        emit Refund(msg.sender, depositedUser);
    }

    // update allocations for the pool
    function updateAllocations(
        bytes memory _addresses,
        bytes memory _amounts
    ) public onlyRole(managerRole) {
        address[] memory addresses = abi.decode(_addresses, (address[]));
        uint256[] memory amounts = abi.decode(_amounts, (uint256[]));

        require(
            addresses.length == amounts.length,
            "Addresses and amounts length mismatch"
        );

        for (uint256 index = 0; index < addresses.length; index++) {
            allocations[addresses[index]] = Allocation({
                userAddress: addresses[index],
                amount: amounts[index]
            });
        }
    }

    function transferOwnership(address newOwner) public virtual override onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        require(newOwner != owner(), "Ownable: new owner is the current owner");
        _grantRole(DEFAULT_ADMIN_ROLE, newOwner);
        _transferOwnership(newOwner);
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // add role manager
    function addManager(address manager) public onlyOwner {
        grantRole(managerRole, manager);
    }

    // remove role manager
    function removeManager(address manager) public onlyOwner {
        revokeRole(managerRole, manager);
    }

    // withdraw funds only owner
    function withdrawFunds(
        address _to,
        address _token,
        uint256 _amount
    ) public onlyOwner {
        require(_to != address(0), "Invalid address");
        if (_token == address(0)) {
            payable(_to).transfer(_amount);
        } else {
            TransferHelper.safeTransfer(_token, _to, _amount);
        }
        emit WithdrawFunds(_to, _amount, _token);
    }
}
