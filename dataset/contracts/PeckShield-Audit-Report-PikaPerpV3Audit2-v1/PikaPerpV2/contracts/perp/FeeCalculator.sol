// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../oracle/IOracle.sol";
import "../access/Governable.sol";

contract FeeCalculator is Governable {

    uint256 public constant PRICE_BASE = 10000;
    address public owner;
    address public keeper;
    bool public isDiscountEnabled = false;
    mapping (address => uint256) public accountFeeDiscount;

    uint256 public MAX_ACCOUNT_DISCOUNT = 5000; // 50%

    event SetIsDiscountEnabled(bool isDiscountEnabled);
    event SetDiscountForAccount(address indexed account, uint256 discount);
    event SetOwner(address indexed owner);
    event SetKeeper(address indexed keeper);

    constructor() public {
        owner = msg.sender;
        keeper = msg.sender;
    }

    /**
     * @notice Get the fee for a token for an account
     * @param token the underlying token for a product
     * @param productFee the default fee for a product
     * @param account the account to open position for. Some accounts may have discount in fees.
     * @param sender the sender of a transaction. Some senders may have discount in fees.
     * @return the total fee rate.
     */
    function getFee(address token, uint256 productFee, address account, address sender) external view returns (uint256) {
        uint256 fee = productFee;
        if (isDiscountEnabled) {
            fee = fee * (PRICE_BASE - accountFeeDiscount[account]) / PRICE_BASE;
        }
        return fee;
    }

    function getDiscounts(address[] calldata accounts) external view returns(uint256[] memory discounts) {
        uint256[] memory discounts = new uint[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            discounts[i] = accountFeeDiscount[accounts[i]];
        }
        return discounts;
    }

    function setIsDiscountEnabled(bool _isDiscountEnabled) external onlyOwner {
        isDiscountEnabled = _isDiscountEnabled;
        emit SetIsDiscountEnabled(_isDiscountEnabled);
    }

    function setDiscountForAccount(address _account, uint256 _discount) public onlyKeeper {
        require(_discount <= MAX_ACCOUNT_DISCOUNT);
        accountFeeDiscount[_account] = _discount;
        emit SetDiscountForAccount(_account, _discount);
    }

    function setDiscounts(address[] calldata _accounts, uint256[] calldata _discounts) external {
        require(_accounts.length == _discounts.length, "not same length");
        for (uint256 i = 0; i < _accounts.length; i++) {
            setDiscountForAccount(_accounts[i], _discounts[i]);
        }
    }

    function setOwner(address _owner) external onlyGov {
        owner = _owner;
        emit SetOwner(_owner);
    }

    function setKeeper(address _keeper) external onlyOwner {
        keeper = _keeper;
        emit SetKeeper(_keeper);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    modifier onlyKeeper() {
        require(msg.sender == keeper, "!keeper");
        _;
    }
}
