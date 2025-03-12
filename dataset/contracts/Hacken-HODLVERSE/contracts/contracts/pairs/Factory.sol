// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "../interfaces/IFactory.sol";
import "./Core.sol";

contract Factory is IFactory {
    address public override owner;
    address public override buyback;
    address public override money;
    address public override migrator;

    bool public override lpFeeOn;
    uint256 public override swapFee = 40;
    uint256 public override buybackShare = 15;
    //1000 MONEY Tokens
    uint256 public override discountEligibilityBalance = 1000 ether;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );
    event UpdateLPFee(bool lpFeeOn);
    event UpdateMigrator(address _migrator);
    event UpdateBuyback(address _buyback);
    event UpdateOwner(address owner);
    event UpdateMoney(address _money);
    event UpdateSwapFee(uint256 _swapFee);
    event UpdateBuybackShare(uint256 _buybackShare);
    event UpdateDiscountEligibilityBalance(uint256 _discountEligibilityBalance);

    modifier onlyOwner() {
        require(msg.sender == owner, "HODL: FORBIDDEN");
        _;
    }

    constructor(address _money) public {
        require(_money != address(0), "HODL:constructor:: ZERO_ADDRESS_MONEY");

        owner = msg.sender;
        money = _money;
    }

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function pairCodeHash() external pure override returns (bytes32) {
        return keccak256(type(Core).creationCode);
    }

    function createPair(address tokenA, address tokenB)
        external
        override
        returns (address pair)
    {
        require(buyback != address(0), "HODL: BUYBACK_NOT_SET");
        require(tokenA != tokenB, "HODL: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "HODL: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "HODL: PAIR_EXISTS"); // single check is sufficient
        bytes memory bytecode = type(Core).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        Core(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function toggleLpFee() external override onlyOwner {
        lpFeeOn = !lpFeeOn;
        emit UpdateLPFee(lpFeeOn);
    }

    function setMigrator(address _migrator) external override onlyOwner {
        migrator = _migrator;
        emit UpdateMigrator(_migrator);
    }

    function setBuyback(address _buyback) external override onlyOwner {
        buyback = _buyback;
        emit UpdateBuyback(_buyback);
    }

    function setOwner(address _owner) external override onlyOwner {
        owner = _owner;
        emit UpdateOwner(_owner);
    }

    function setMoney(address _money) external override onlyOwner {
        money = _money;
        emit UpdateMoney(_money);
    }

    function setSwapFee(uint256 _swapFee) external override onlyOwner {
        swapFee = _swapFee;
        emit UpdateSwapFee(_swapFee);
    }

    function setBuybackShare(uint256 _buybackShare)
        external
        override
        onlyOwner
    {
        buybackShare = _buybackShare;
        emit UpdateBuybackShare(_buybackShare);
    }

    function setDiscountEligibilityBalance(uint256 _discountEligibilityBalance)
        external
        override
        onlyOwner
    {
        discountEligibilityBalance = _discountEligibilityBalance;
        emit UpdateDiscountEligibilityBalance(_discountEligibilityBalance);
    }

    function getSwapFee(address _user)
        external
        view
        override
        returns (uint256, uint256)
    {
        if (IERC20(money).balanceOf(_user) > discountEligibilityBalance) {
            return (swapFee / 2, buybackShare / 2);
        } else {
            return (swapFee, buybackShare);
        }
    }
}
