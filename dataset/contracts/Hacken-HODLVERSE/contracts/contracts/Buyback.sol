// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./interfaces/IBuyback.sol";
import "./interfaces/IFactory.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract Buyback is IBuyback, Ownable, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IRouter public override router;
    IReserve public override reserve;
    address public override money;

    event UpdateReserve(address _reserve);
    event UpdateRouter(address _router);
    event UpdateMoney(address _money);

    event TransferMoneyToReserve(uint256 toTransfer);

    modifier isInitialised() {
        require(
            address(reserve) != address(0),
            "Buyback:isInitialised:: ERR_RESERVE_NOT_SET"
        );
        _;
    }

    constructor(address _router, address _money) public {
        require(
            _router != address(0),
            "Buyback:constructor:: ERR_ZERO_ADDRESS_ROUTER"
        );
        require(
            _money != address(0),
            "Buyback:constructor:: ERR_ZERO_ADDRESS_MONEY"
        );

        router = IRouter(_router);
        money = _money;
    }

    function setReserve(address _newAddress) external override onlyOwner {
        require(
            _newAddress != address(0),
            "Buyback:setReserve:: ERR_ZERO_ADDR"
        );
        reserve = IReserve(_newAddress);
        emit UpdateReserve(_newAddress);
    }

    function updateMoney(address _newAddress) external override onlyOwner {
        require(
            _newAddress != address(0),
            "Buyback:updateMoney:: ERR_ZERO_ADDR"
        );
        money = _newAddress;
        emit UpdateMoney(_newAddress);
    }

    function updateRouter(address _newAddress) external override onlyOwner {
        require(
            _newAddress != address(0),
            "Buyback:updateRouter:: ERR_ZERO_ADDR"
        );
        router = IRouter(_newAddress);
        emit UpdateRouter(_newAddress);
    }

    function swapTokens(
        uint256 minOut,
        address token,
        address[] memory path
    )
        external
        override
        onlyOwner
        whenNotPaused
        isInitialised
        returns (uint256 amountOut)
    {
        if (token == money) return transferMoneyToReserve();

        require(
            path[path.length - 1] == money,
            "Buyback:swapAndSendToReserve:: ERR_NOT_MONEY"
        );
        require(
            token != address(0),
            "Buyback:swapAndSendToReserve:: ERR_INVALID_TOKEN_ADDRESS"
        );
        require(
            path.length != 0,
            "Buyback:swapAndSendToReserve:: ERR_INVALID_PATH"
        );
        require(
            path[path.length - 1] != path[0],
            "Buyback:swapAndSendToReserve:: ERR_SAME_TOKEN_SWAP"
        );

        uint256 toSwap = IERC20(token).balanceOf(address(this));
        if (toSwap == 0) return 0;

        IERC20(token).approve(address(router), toSwap);
        amountOut = _swap(toSwap, path, minOut);
    }

    function _swap(
        uint256 _amountIn,
        address[] memory _path,
        uint256 _minOut
    ) internal returns (uint256) {
        uint256[] memory amountOut = router.swapExactTokensForTokens(
            _amountIn,
            _minOut,
            _path,
            address(this),
            block.timestamp
        );

        return amountOut[_path.length - 1];
    }

    function removeLiquidity(
        address _token0,
        address _token1,
        uint256 _minToken0Out,
        uint256 _minToken1Out
    )
        external
        override
        whenNotPaused
        isInitialised
        returns (uint256 amount0Out, uint256 amount1Out)
    {
        require(
            _token0 != address(0) && _token1 != address(0),
            "Buyback:removeLiquidity:: ERR_INVALID_TOKEN_ADDRESS"
        );
        require(
            _minToken0Out != 0 && _minToken1Out != 0,
            "Buyback:removeLiquidity:: ERR_INVALID_AMOUNTS"
        );

        (amount0Out, amount1Out) = _removeLiquidity(
            _token0,
            _token1,
            _minToken0Out,
            _minToken1Out
        );
    }

    function _removeLiquidity(
        address _token0,
        address _token1,
        uint256 _minToken0Out,
        uint256 _minToken1Out
    ) internal returns (uint256 amountA, uint256 amountB) {
        address pair = IFactory(router.factory()).getPair(_token0, _token1);
        uint256 amount = IERC20(pair).balanceOf(address(this));
        IERC20(pair).approve(address(router), amount);

        (amountA, amountB) = router.removeLiquidity(
            _token0,
            _token1,
            amount,
            _minToken0Out,
            _minToken1Out,
            address(this),
            block.timestamp
        );
    }

    function transferMoneyToReserve()
        public
        override
        whenNotPaused
        isInitialised
        returns (uint256 toTransfer)
    {
        toTransfer = IERC20(money).balanceOf(address(this));

        require(
            toTransfer != 0,
            "Buyback:transferMoneyToReserve:: ERR_OUT_OF_BALANCE"
        );

        IERC20(money).safeTransfer(address(reserve), toTransfer);
        reserve.deposit(toTransfer);

        emit TransferMoneyToReserve(toTransfer);
    }

    function inCaseTokensGetStuck(address _token, address payable _to)
        external
        override
        onlyOwner
    {
        uint256 contractBalance;
        if (_token == address(0)) {
            contractBalance = address(this).balance;
            _to.transfer(contractBalance);
        } else {
            contractBalance = IERC20(_token).balanceOf(address(this));
            IERC20(_token).safeTransfer(_to, contractBalance);
        }
    }
}
