pragma solidity 0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {INeuronPool} from "../interfaces/INeuronPool.sol";
import {IStakingRewards} from "../interfaces/IStakingRewards.sol";
import {IUniswapRouterV2} from "../interfaces/IUniswapRouterV2.sol";
import {IController} from "../interfaces/IController.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";

// Strategy Contract Basics

abstract contract StrategyBase is IStrategy {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    // Perfomance fees - start with 30%
    uint256 public performanceTreasuryFee = 3000;
    uint256 public constant performanceTreasuryMax = 10000;

    // Withdrawal fee 0%
    // - 0% to treasury
    // - 0% to dev fund
    uint256 public withdrawalTreasuryFee = 0;
    uint256 public constant withdrawalTreasuryMax = 100000;

    uint256 public withdrawalDevFundFee = 0;
    uint256 public constant withdrawalDevFundMax = 100000;

    // Tokens
    // Input token accepted by the contract
    address public immutable neuronTokenAddress;
    address public immutable want;
    address public constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // User accounts
    address public governance;
    address public controller;
    address public strategist;
    address public timelock;

    // Dex
    address public constant univ2Router2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public constant sushiRouter = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;

    mapping(address => bool) public harvesters;

    constructor(
        // Input token accepted by the contract
        address _want,
        address _governance,
        address _strategist,
        address _controller,
        address _neuronTokenAddress,
        address _timelock
    ) {
        require(_want != address(0));
        require(_governance != address(0));
        require(_strategist != address(0));
        require(_controller != address(0));
        require(_neuronTokenAddress != address(0));
        require(_timelock != address(0));

        want = _want;
        governance = _governance;
        strategist = _strategist;
        controller = _controller;
        neuronTokenAddress = _neuronTokenAddress;
        timelock = _timelock;
    }

    receive() external payable {}

    // **** Modifiers **** //

    modifier onlyBenevolent() {
        require(harvesters[msg.sender] || msg.sender == governance || msg.sender == strategist);
        _;
    }

    // **** Views **** //

    function balanceOfWant() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    function balanceOfPool() public view virtual returns (uint256);

    function balanceOf() public view returns (uint256) {
        return balanceOfWant().add(balanceOfPool());
    }

    function getName() external pure virtual returns (string memory);

    // **** Setters **** //

    function whitelistHarvester(address _harvester) external {
        require(msg.sender == governance || msg.sender == strategist, "not authorized");
        harvesters[_harvester] = true;
    }

    function revokeHarvester(address _harvester) external {
        require(msg.sender == governance || msg.sender == strategist, "not authorized");
        harvesters[_harvester] = false;
    }

    function setWithdrawalDevFundFee(uint256 _withdrawalDevFundFee) external {
        require(msg.sender == timelock, "!timelock");
        withdrawalDevFundFee = _withdrawalDevFundFee;
    }

    function setWithdrawalTreasuryFee(uint256 _withdrawalTreasuryFee) external {
        require(msg.sender == timelock, "!timelock");
        withdrawalTreasuryFee = _withdrawalTreasuryFee;
    }

    function setPerformanceTreasuryFee(uint256 _performanceTreasuryFee) external {
        require(msg.sender == timelock, "!timelock");
        performanceTreasuryFee = _performanceTreasuryFee;
    }

    function setStrategist(address _strategist) external {
        require(msg.sender == governance, "!governance");
        strategist = _strategist;
    }

    function setGovernance(address _governance) external {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    function setTimelock(address _timelock) external {
        require(msg.sender == timelock, "!timelock");
        timelock = _timelock;
    }

    function setController(address _controller) external {
        require(msg.sender == timelock, "!timelock");
        controller = _controller;
    }

    // **** State mutations **** //
    function deposit() public virtual;

    // Controller only function for creating additional rewards from dust
    function withdraw(address _asset) external returns (uint256 balance) {
        require(msg.sender == controller, "!controller");
        require(want != _asset, "want");
        balance = IERC20(_asset).balanceOf(address(this));
        IERC20(_asset).safeTransfer(controller, balance);
    }

    // Withdraw partial funds, normally used with a pool withdrawal
    function withdraw(uint256 _amount) external {
        require(msg.sender == controller, "!controller");
        uint256 _balance = IERC20(want).balanceOf(address(this));
        if (_balance < _amount) {
            _amount = _withdrawSome(_amount.sub(_balance));
            _amount = _amount.add(_balance);
        }

        uint256 _feeDev = _amount.mul(withdrawalDevFundFee).div(withdrawalDevFundMax);
        IERC20(want).safeTransfer(IController(controller).devfund(), _feeDev);

        uint256 _feeTreasury = _amount.mul(withdrawalTreasuryFee).div(withdrawalTreasuryMax);
        IERC20(want).safeTransfer(IController(controller).treasury(), _feeTreasury);

        address _nPool = IController(controller).nPools(address(want));
        require(_nPool != address(0), "!nPool"); // additional protection so we don't burn the funds

        uint256 total = _amount.sub(_feeDev).sub(_feeTreasury);
        IERC20(want).safeTransfer(_nPool, total);

        emit Withdraw(_amount, total);
    }

    // Withdraw funds, used to swap between strategies
    function withdrawForSwap(uint256 _amount) external returns (uint256 balance) {
        require(msg.sender == controller, "!controller");
        _withdrawSome(_amount);

        balance = IERC20(want).balanceOf(address(this));

        address _nPool = IController(controller).nPools(address(want));
        require(_nPool != address(0), "!nPool");
        IERC20(want).safeTransfer(_nPool, balance);
    }

    // Withdraw all funds, normally used when migrating strategies
    function withdrawAll() external returns (uint256 balance) {
        require(msg.sender == controller, "!controller");
        _withdrawAll();

        balance = IERC20(want).balanceOf(address(this));

        address _nPool = IController(controller).nPools(address(want));
        require(_nPool != address(0), "!nPool"); // additional protection so we don't burn the funds
        IERC20(want).safeTransfer(_nPool, balance);
    }

    function _withdrawAll() internal {
        _withdrawSome(balanceOfPool());
    }

    function _withdrawSome(uint256 _amount) internal virtual returns (uint256);

    function harvest() public virtual;

    // **** Emergency functions ****

    function execute(address _target, bytes memory _data) public payable returns (bytes memory response) {
        require(msg.sender == timelock, "!timelock");
        require(_target != address(0), "!target");

        // call contract in current context
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

    // **** Internal functions ****
    function _swapUniswap(
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        require(_to != address(0));

        address[] memory path;

        if (_from == weth || _to == weth) {
            path = new address[](2);
            path[0] = _from;
            path[1] = _to;
        } else {
            path = new address[](3);
            path[0] = _from;
            path[1] = weth;
            path[2] = _to;
        }

        IUniswapRouterV2(univ2Router2).swapExactTokensForTokens(
            _amount,
            0,
            path,
            address(this),
            block.timestamp.add(60)
        );
    }

    function _swapUniswapExactETHForTokens(address _to, uint256 _amount) internal {
        require(_to != address(0));

        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = _to;

        IUniswapRouterV2(univ2Router2).swapExactETHForTokens{value: _amount}(
            0,
            path,
            address(this),
            block.timestamp.add(60)
        );
    }

    function _swapUniswapExactTokensForETH(address _from, uint256 _amount) internal {
        require(_from != address(0));

        address[] memory path = new address[](2);
        path[0] = _from;
        path[1] = weth;

        IUniswapRouterV2(univ2Router2).swapExactTokensForETH(_amount, 0, path, address(this), block.timestamp.add(60));
    }

    function _swapUniswapWithPath(address[] memory path, uint256 _amount) internal {
        require(path[1] != address(0));

        IUniswapRouterV2(univ2Router2).swapExactTokensForTokens(
            _amount,
            0,
            path,
            address(this),
            block.timestamp.add(60)
        );
    }

    function _swapSushiswap(
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        require(_to != address(0));

        address[] memory path;

        if (_from == weth || _to == weth) {
            path = new address[](2);
            path[0] = _from;
            path[1] = _to;
        } else {
            path = new address[](3);
            path[0] = _from;
            path[1] = weth;
            path[2] = _to;
        }

        IUniswapRouterV2(sushiRouter).swapExactTokensForTokens(
            _amount,
            0,
            path,
            address(this),
            block.timestamp.add(60)
        );
    }

    function _swapWithUniLikeRouter(
        address routerAddress,
        address _from,
        address _to,
        uint256 _amount
    ) internal returns (bool) {
        require(_to != address(0));
        require(routerAddress != address(0), "_swapWithUniLikeRouter routerAddress cant be zero");

        address[] memory path;

        if (_from == weth || _to == weth) {
            path = new address[](2);
            path[0] = _from;
            path[1] = _to;
        } else {
            path = new address[](3);
            path[0] = _from;
            path[1] = weth;
            path[2] = _to;
        }

        try
            IUniswapRouterV2(routerAddress).swapExactTokensForTokens(
                _amount,
                0,
                path,
                address(this),
                block.timestamp.add(60)
            )
        {
            return true;
        } catch {
            return false;
        }
    }

    function _swapSushiswapWithPath(address[] memory path, uint256 _amount) internal {
        require(path[1] != address(0));

        IUniswapRouterV2(sushiRouter).swapExactTokensForTokens(
            _amount,
            0,
            path,
            address(this),
            block.timestamp.add(60)
        );
    }

    function _swapToNeurAndDistributePerformanceFees(address swapToken, address swapRouterAddress) internal {
        uint256 swapTokenBalance = IERC20(swapToken).balanceOf(address(this));

        if (swapTokenBalance > 0 && performanceTreasuryFee > 0) {
            uint256 performanceTreasuryFeeAmount = swapTokenBalance.mul(performanceTreasuryFee).div(
                performanceTreasuryMax
            );
            uint256 totalFeeAmout = performanceTreasuryFeeAmount;

            _swapAmountToNeurAndDistributePerformanceFees(swapToken, totalFeeAmout, swapRouterAddress);
        }
    }

    function _swapAmountToNeurAndDistributePerformanceFees(
        address swapToken,
        uint256 amount,
        address swapRouterAddress
    ) internal {
        uint256 swapTokenBalance = IERC20(swapToken).balanceOf(address(this));

        require(swapTokenBalance >= amount, "Amount is bigger than token balance");

        IERC20(swapToken).safeApprove(swapRouterAddress, 0);
        IERC20(weth).safeApprove(swapRouterAddress, 0);
        IERC20(swapToken).safeApprove(swapRouterAddress, amount);
        IERC20(weth).safeApprove(swapRouterAddress, type(uint256).max);
        bool isSuccesfullSwap = _swapWithUniLikeRouter(swapRouterAddress, swapToken, neuronTokenAddress, amount);

        if (isSuccesfullSwap) {
            uint256 neuronTokenBalance = IERC20(neuronTokenAddress).balanceOf(address(this));

            if (neuronTokenBalance > 0) {
                // Treasury fees
                // Sending strategy's tokens to treasury. Initially @ 30% (set by performanceTreasuryFee constant) of strategy's assets
                IERC20(neuronTokenAddress).safeTransfer(IController(controller).treasury(), neuronTokenBalance);
            }
        } else {
            // If failed swap to Neuron just transfer swap token to treasury
            IERC20(swapToken).safeApprove(IController(controller).treasury(), 0);
            IERC20(swapToken).safeApprove(IController(controller).treasury(), amount);
            IERC20(swapToken).safeTransfer(IController(controller).treasury(), amount);
        }
    }
}
