// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./AddressAccessor.sol";
import "./constants/addresses.sol";
import "./USDRExchange.sol";
import "./interfaces/IPriceOracle.sol";

interface IBatchSender {
    function send(
        address token,
        uint256 total,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external;
}

interface IExchangeProxy {
    function swapFromToken(
        address token,
        uint256 amountIn,
        uint256 minAmountOut,
        address to
    ) external returns (uint256 amountOut);
}

contract AffiliateExchange is Pausable, AddressAccessor {
    event Mint(
        address indexed tokenIn,
        address indexed minter,
        uint256 indexed timestamp,
        address receiver,
        uint256 amountIn,
        uint256 amountOut,
        uint256 affiliatePayout
    );

    uint256 private _pending;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver,
        uint256 affiliatePayout,
        uint256 timestamp,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external whenNotPaused {
        {
            bytes32 hash = keccak256(
                abi.encodePacked(
                    msg.sender,
                    tokenIn,
                    amountIn,
                    affiliatePayout,
                    timestamp
                )
            );
            bytes32 messageDigest = keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
            );
            address signer = addressProvider.getAddress(
                bytes32(keccak256("affiliateSigner"))
            );
            require(signer == ecrecover(messageDigest, v, r, s));
        }
        uint256 amountOut = _mint(
            tokenIn,
            amountIn,
            minAmountOut,
            receiver,
            affiliatePayout
        );

        emit Mint(
            tokenIn,
            msg.sender,
            timestamp,
            receiver,
            amountIn,
            amountOut,
            affiliatePayout
        );
    }

    function pause() external whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external whenPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function sendRewards(
        address batchSender,
        uint256 total,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external whenNotPaused onlyRole(CONTROLLER_ROLE) {
        address usdr = addressProvider.getAddress(USDR_ADDRESS);
        IERC20(usdr).approve(batchSender, total);
        IBatchSender(batchSender).send(usdr, total, recipients, amounts);
        _pending -= total;
    }

    function withdrawExcessUSDR() external onlyRole(DEFAULT_ADMIN_ROLE) {
        address usdr = addressProvider.getAddress(USDR_ADDRESS);
        uint256 excessUSDR = IERC20(usdr).balanceOf(address(this)) - _pending;
        IERC20(usdr).transfer(msg.sender, excessUSDR);
    }

    function withdrawToken(address token)
        external
        whenPaused
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        IERC20 erc20 = IERC20(token);
        uint256 balance = erc20.balanceOf(address(this));
        require(balance > 0);
        erc20.transfer(msg.sender, balance);
    }

    function _mint(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver,
        uint256 affiliatePayout
    ) private returns (uint256 amountOut) {
        (
            address underlying,
            address exchange,
            address tngbl,
            address oracle,
            address usdr
        ) = abi.decode(
                addressProvider.getAddresses(
                    abi.encode(
                        UNDERLYING_ADDRESS,
                        USDR_EXCHANGE_ADDRESS,
                        TNGBL_ADDRESS,
                        TNGBL_ORACLE_ADDRESS,
                        USDR_ADDRESS
                    )
                ),
                (address, address, address, address, address)
            );

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // mint USDR for minter
        if (tokenIn == underlying) {
            IERC20(underlying).approve(exchange, amountIn);
            amountOut = IExchange(exchange).swapFromUnderlying(
                amountIn,
                receiver
            );
        } else {
            address exchangeProxy = addressProvider.getAddress(
                keccak256("USDRExchangeProxy")
            );
            IERC20(tokenIn).approve(exchangeProxy, amountIn);
            amountOut = IExchangeProxy(exchangeProxy).swapFromToken(
                tokenIn,
                amountIn,
                minAmountOut,
                receiver
            );
        }

        // mint extra USDR for affiliates if needed
        uint256 excessUSDR;
        uint256 usdrBalance = IERC20(usdr).balanceOf(address(this));
        if (usdrBalance >= _pending) {
            excessUSDR = usdrBalance - _pending;
        }
        if (affiliatePayout > excessUSDR) {
            uint256 mintExtra = affiliatePayout - excessUSDR;
            uint256 tngblPrice = IPriceOracle(oracle).quote(1e18);
            uint256 mintExtraInTNGBL = (mintExtra * 1e27) / tngblPrice;
            IERC20(tngbl).approve(exchange, mintExtraInTNGBL);
            USDRExchange(exchange).swapFromTNGBL(
                mintExtraInTNGBL,
                0,
                address(this)
            );
        }
        _pending += affiliatePayout;
    }
}
