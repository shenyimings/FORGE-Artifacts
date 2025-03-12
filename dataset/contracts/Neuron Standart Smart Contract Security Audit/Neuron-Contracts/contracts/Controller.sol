pragma solidity 0.8.9;

pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IController} from "./interfaces/IController.sol";
import {INeuronPool} from "./interfaces/INeuronPool.sol";
import {INeuronPoolConverter} from "./interfaces/INeuronPoolConverter.sol";
import {IOneSplitAudit} from "./interfaces/IOneSplitAudit.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {IConverter} from "./interfaces/IConverter.sol";

// Deployed once (in contrast with nPools - those are created individually for each strategy).
// Then new nPools are added via setNPool function
contract Controller {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public constant burn = 0x000000000000000000000000000000000000dEaD;
    address public onesplit = 0xC586BeF4a0992C495Cf22e1aeEE4E446CECDee0E;

    address public governance;
    address public strategist;
    address public devfund;
    address public treasury;
    address public timelock;

    // Convenience fee 0.1%
    uint256 public convenienceFee = 100;
    uint256 public constant convenienceFeeMax = 100000;

    mapping(address => address) public nPools;
    mapping(address => address) public strategies;
    mapping(address => mapping(address => address)) public converters;
    mapping(address => mapping(address => bool)) public approvedStrategies;
    mapping(address => bool) public approvedNPoolConverters;

    uint256 public split = 500;
    uint256 public constant max = 10000;

    constructor(
        address _governance,
        address _strategist,
        address _timelock,
        address _devfund,
        address _treasury
    ) {
        governance = _governance;
        strategist = _strategist;
        timelock = _timelock;
        devfund = _devfund;
        treasury = _treasury;
    }

    function setDevFund(address _devfund) public {
        require(msg.sender == governance, "!governance");
        devfund = _devfund;
    }

    function setTreasury(address _treasury) public {
        require(msg.sender == governance, "!governance");
        treasury = _treasury;
    }

    function setStrategist(address _strategist) public {
        require(msg.sender == governance, "!governance");
        strategist = _strategist;
    }

    function setSplit(uint256 _split) public {
        require(msg.sender == governance, "!governance");
        require(_split <= max, "numerator cannot be greater than denominator");
        split = _split;
    }

    function setOneSplit(address _onesplit) public {
        require(msg.sender == governance, "!governance");
        onesplit = _onesplit;
    }

    function setGovernance(address _governance) public {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    function setTimelock(address _timelock) public {
        require(msg.sender == timelock, "!timelock");
        timelock = _timelock;
    }

    function setNPool(address _token, address _nPool) public {
        require(msg.sender == strategist || msg.sender == governance, "!strategist");
        require(nPools[_token] == address(0), "nPool");
        nPools[_token] = _nPool;
    }

    function approveNPoolConverter(address _converter) public {
        require(msg.sender == governance, "!governance");
        approvedNPoolConverters[_converter] = true;
    }

    function revokeNPoolConverter(address _converter) public {
        require(msg.sender == governance, "!governance");
        approvedNPoolConverters[_converter] = false;
    }

    // Called before adding strategy to controller, turns the strategy 'on-off'
    // We're in need of an additional array for strategies' on-off states (are we?)
    // Called when deploying
    function approveStrategy(address _token, address _strategy) public {
        require(msg.sender == timelock, "!timelock");
        approvedStrategies[_token][_strategy] = true;
    }

    // Turns off/revokes strategy
    function revokeStrategy(address _token, address _strategy) public {
        require(msg.sender == governance, "!governance");
        require(strategies[_token] != _strategy, "cannot revoke active strategy");
        approvedStrategies[_token][_strategy] = false;
    }

    function setConvenienceFee(uint256 _convenienceFee) external {
        require(msg.sender == timelock, "!timelock");
        convenienceFee = _convenienceFee;
    }

    // Adding or updating a strategy
    function setStrategy(address _token, address _strategy) public {
        require(msg.sender == strategist || msg.sender == governance, "!strategist");
        require(approvedStrategies[_token][_strategy] == true, "!approved");

        address _current = strategies[_token];
        if (_current != address(0)) {
            IStrategy(_current).withdrawAll();
        }
        strategies[_token] = _strategy;
    }

    // Depositing token to a pool
    function earn(address _token, uint256 _amount) public {
        address _strategy = strategies[_token];
        // Token needed for strategy
        address _want = IStrategy(_strategy).want();
        if (_want != _token) {
            // Convert if token other than wanted deposited
            address converter = converters[_token][_want];
            IERC20(_token).safeTransfer(converter, _amount);
            _amount = IConverter(converter).convert(_strategy);
            IERC20(_want).safeTransfer(_strategy, _amount);
        } else {
            // Transferring to the strategy address
            IERC20(_token).safeTransfer(_strategy, _amount);
        }
        // Calling deposit @ strategy
        IStrategy(_strategy).deposit();
    }

    function balanceOf(address _token) external view returns (uint256) {
        return IStrategy(strategies[_token]).balanceOf();
    }

    function withdrawAll(address _token) public {
        require(msg.sender == strategist || msg.sender == governance, "!strategist");
        IStrategy(strategies[_token]).withdrawAll();
    }

    function inCaseTokensGetStuck(address _token, uint256 _amount) public {
        require(msg.sender == strategist || msg.sender == governance, "!governance");
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    function inCaseStrategyTokenGetStuck(address _strategy, address _token) public {
        require(msg.sender == strategist || msg.sender == governance, "!governance");
        IStrategy(_strategy).withdraw(_token);
    }

    function getExpectedReturn(
        address _strategy,
        address _token,
        uint256 parts
    ) public view returns (uint256 expected) {
        uint256 _balance = IERC20(_token).balanceOf(_strategy);
        address _want = IStrategy(_strategy).want();
        (expected, ) = IOneSplitAudit(onesplit).getExpectedReturn(_token, _want, _balance, parts, 0);
    }

    // Only allows to withdraw non-core strategy tokens and send to treasury ~ this is over and above normal yield
    function yearn(
        address _strategy,
        address _token,
        uint256 parts
    ) public {
        require(msg.sender == strategist || msg.sender == governance, "!governance");
        // This contract should never have value in it, but just incase since this is a public call
        uint256 _before = IERC20(_token).balanceOf(address(this));
        IStrategy(_strategy).withdraw(_token);
        uint256 _after = IERC20(_token).balanceOf(address(this));
        if (_after > _before) {
            uint256 _amount = _after.sub(_before);
            address _want = IStrategy(_strategy).want();
            uint256[] memory _distribution;
            uint256 _expected;
            _before = IERC20(_want).balanceOf(address(this));
            IERC20(_token).safeApprove(onesplit, 0);
            IERC20(_token).safeApprove(onesplit, _amount);
            (_expected, _distribution) = IOneSplitAudit(onesplit).getExpectedReturn(_token, _want, _amount, parts, 0);
            IOneSplitAudit(onesplit).swap(_token, _want, _amount, _expected, _distribution, 0);
            _after = IERC20(_want).balanceOf(address(this));
            if (_after > _before) {
                _amount = _after.sub(_before);
                uint256 _treasury = _amount.mul(split).div(max);
                earn(_want, _amount.sub(_treasury));
                IERC20(_want).safeTransfer(treasury, _treasury);
            }
        }
    }

    function withdraw(address _token, uint256 _amount) public {
        require(msg.sender == nPools[_token], "!nPool");
        IStrategy(strategies[_token]).withdraw(_amount);
    }

    // Function to swap between nPools
    // Seems to be called when a new version of NPool is created
    // With NPool functioning, unwanted tokens are sometimes landing here; this function helps transfer them to another pool
    // A transaction example https://etherscan.io/tx/0xc6f15e55f8520bc22a0bb9ac15b6f3fd80a0295e5c40b0e255eb7f3be34733f2
    // https://etherscan.io/txs?a=0x6847259b2B3A4c17e7c43C54409810aF48bA5210&ps=100&p=3 - Pickle's transaction calls
    // Last called ~140 days ago
    // Seems to be the culprit of recent Pickle's attack https://twitter.com/n2ckchong/status/1330244058669850624?lang=en
    // Googling the function returns some hack explanations https://halborn.com/category/explained-hacks/
    // >The problem with this function is that it doesnâ€™t check the validity of the nPools presented to it
    function swapExactNPoolForNPool(
        address _fromNPool, // From which NPool
        address _toNPool, // To which NPool
        uint256 _fromNPoolAmount, // How much nPool tokens to swap
        uint256 _toNPoolMinAmount, // How much nPool tokens you'd like at a minimum
        address payable[] calldata _targets, // targets - converters' contract addresses
        bytes[] calldata _data
    ) external returns (uint256) {
        require(_targets.length == _data.length, "!length");

        // Only return last response
        for (uint256 i = 0; i < _targets.length; i++) {
            require(_targets[i] != address(0), "!converter");
            require(approvedNPoolConverters[_targets[i]], "!converter");
        }

        address _fromNPoolToken = INeuronPool(_fromNPool).token();
        address _toNPoolToken = INeuronPool(_toNPool).token();

        // Get pTokens from msg.sender
        IERC20(_fromNPool).safeTransferFrom(msg.sender, address(this), _fromNPoolAmount);

        // Calculate how much underlying
        // is the amount of pTokens worth
        uint256 _fromNPoolUnderlyingAmount = _fromNPoolAmount.mul(INeuronPool(_fromNPool).pricePerShare()).div(
            10**uint256(INeuronPool(_fromNPool).decimals())
        );

        // Call 'withdrawForSwap' on NPool's current strategy if NPool
        // doesn't have enough initial capital.
        // This has moves the funds from the strategy to the NPool's
        // 'earnable' amount. Enabling 'free' withdrawals
        uint256 _fromNPoolAvailUnderlying = IERC20(_fromNPoolToken).balanceOf(_fromNPool);
        if (_fromNPoolAvailUnderlying < _fromNPoolUnderlyingAmount) {
            IStrategy(strategies[_fromNPoolToken]).withdrawForSwap(
                _fromNPoolUnderlyingAmount.sub(_fromNPoolAvailUnderlying)
            );
        }

        // Withdraw from NPool
        // Note: this is free since its still within the "earnable" amount
        //       as we transferred the access
        IERC20(_fromNPool).safeApprove(_fromNPool, 0);
        IERC20(_fromNPool).safeApprove(_fromNPool, _fromNPoolAmount);
        INeuronPool(_fromNPool).withdraw(_toNPoolToken, _fromNPoolAmount);

        // Calculate fee
        uint256 _fromUnderlyingBalance = IERC20(_fromNPoolToken).balanceOf(address(this));
        uint256 _convenienceFee = _fromUnderlyingBalance.mul(convenienceFee).div(convenienceFeeMax);

        if (_convenienceFee > 1) {
            IERC20(_fromNPoolToken).safeTransfer(devfund, _convenienceFee.div(2));
            IERC20(_fromNPoolToken).safeTransfer(treasury, _convenienceFee.div(2));
        }

        // Executes sequence of logic
        for (uint256 i = 0; i < _targets.length; i++) {
            _execute(_targets[i], _data[i]);
        }

        // Deposit into new NPool
        uint256 _toBal = IERC20(_toNPoolToken).balanceOf(address(this));
        IERC20(_toNPoolToken).safeApprove(_toNPool, 0);
        IERC20(_toNPoolToken).safeApprove(_toNPool, _toBal);
        INeuronPool(_toNPool).deposit(_toNPoolToken, _toBal);

        // Send NPool Tokens to user
        uint256 _toNPoolBal = INeuronPool(_toNPool).balanceOf(address(this));
        if (_toNPoolBal < _toNPoolMinAmount) {
            revert("!min-nPool-amount");
        }

        INeuronPool(_toNPool).transfer(msg.sender, _toNPoolBal);

        return _toNPoolBal;
    }

    function _execute(address _target, bytes memory _data) internal returns (bytes memory response) {
        require(_target != address(0), "!target");

        // Call contract in current context
        assembly {
            let succeeded := delegatecall(sub(gas(), 5000), _target, add(_data, 0x20), mload(_data), 0, 0)
            let size := returndatasize()

            response := mload(0x40)
            mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)

            switch iszero(succeeded)
            case 1 {
                // throw if delegatecall failed
                revert(add(response, 0x20), size)
            }
        }
    }
}
