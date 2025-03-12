// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./constants/addresses.sol";
import "./constants/roles.sol";
import "./interfaces/IExchange.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IUSDR.sol";
import "./tokens/interfaces/IMintableERC20.sol";
import "./AddressAccessor.sol";

contract USDRExchange is AddressAccessor, IExchange, Pausable {
    using SafeERC20 for IERC20;

    struct MintingStats {
        uint256 tngblToUSDR;
        uint256 underlyingToUSDR;
        uint256 usdrToPromissory;
        uint256 usdrToTNGBL;
        uint256 usdrToUnderlying;
        uint256 usdrFromGains;
        uint256 usdrFromRebase;
    }

    uint256 public depositFee; // 1% = 100
    uint256 public withdrawalFee;

    uint256 private _scale;

    MintingStats public mintingStats;

    constructor(USDRExchange previousImpl) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        if (address(previousImpl) != address(0)) {
            (
                uint256 tngblToUSDR,
                uint256 underlyingToUSDR,
                uint256 usdrToPromissory,
                uint256 usdrToTNGBL,
                uint256 usdrToUnderlying,
                uint256 usdrFromGains,
                uint256 usdrFromRebase
            ) = previousImpl.mintingStats();
            mintingStats = MintingStats({
                tngblToUSDR: tngblToUSDR,
                underlyingToUSDR: underlyingToUSDR,
                usdrToPromissory: usdrToPromissory,
                usdrToTNGBL: usdrToTNGBL,
                usdrToUnderlying: usdrToUnderlying,
                usdrFromGains: usdrFromGains,
                usdrFromRebase: usdrFromRebase
            });
            depositFee = previousImpl.depositFee();
            withdrawalFee = previousImpl.withdrawalFee();
        }
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function scaleFromUnderlying(uint256 amount)
        external
        view
        returns (uint256)
    {
        return _scaleFromUnderlying(amount);
    }

    function updateMintingStats(int128[7] calldata delta) external {
        require(msg.sender == addressProvider.getAddress(USDR_ADDRESS));
        mintingStats.usdrFromRebase = uint256(
            int256(mintingStats.usdrFromRebase) + delta[6]
        );
    }

    function maxTNGBLMintingAmount() external view returns (uint256) {
        return
            _maxTNGBLMintingAmount(
                addressProvider.getAddress(TNGBL_ORACLE_ADDRESS)
            );
    }

    function mintAgainstGains(uint256 minGain)
        external
        onlyRole(CONTROLLER_ROLE)
    {
        MintingStats memory stats = mintingStats;
        uint256 minted = stats.tngblToUSDR +
            stats.underlyingToUSDR +
            stats.usdrFromGains;
        uint256 reduceBy = stats.usdrToPromissory +
            stats.usdrToTNGBL +
            stats.usdrToUnderlying +
            stats.usdrFromRebase;
        if (minted >= reduceBy) {
            (address treasury, address usdr) = abi.decode(
                addressProvider.getAddresses(
                    abi.encode(TREASURY_ADDRESS, USDR_ADDRESS)
                ),
                (address, address)
            );
            ITreasury.TreasuryValue memory treasuryValue = ITreasury(treasury)
                .getTreasuryValue();
            uint256 total = (treasuryValue.total - treasuryValue.rwaVaults) /
                1e9 -
                stats.usdrFromGains;
            uint256 gains = minted - reduceBy;
            if (gains < total) {
                gains = total - gains;
                if (gains > minGain) {
                    IUSDR(usdr).mint(treasury, gains);
                    mintingStats.usdrFromGains = stats.usdrFromGains + gains;
                    return;
                }
            }
        }
        revert("insufficient gains");
    }

    function scaleToUnderlying(uint256 amount) external view returns (uint256) {
        return _scaleToUnderlying(amount);
    }

    function setFees(uint256 depositFee_, uint256 withdrawalFee_)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        depositFee = depositFee_;
        withdrawalFee = withdrawalFee_;
    }

    function swapToPromissory(uint256 amountIn, address to)
        external
        whenNotPaused
        returns (uint256)
    {
        (address promissory, uint256 amountOut) = _preparePromissoryWithdrawal(
            amountIn
        );
        IMintableERC20(promissory).mint(to, amountOut);
        mintingStats.usdrToPromissory += amountIn;
        return amountOut;
    }

    function swapToTNGBL(
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) external whenNotPaused returns (uint256) {
        (
            address treasury,
            address tngbl,
            uint256 amountOut
        ) = _prepareTNGBLWithdrawal(amountIn);
        require(amountOut >= amountOutMin, "insufficient output amount");
        ITreasury(treasury).withdraw(tngbl, amountOut, to);
        mintingStats.usdrToTNGBL += amountIn;
        return amountOut;
    }

    function swapToUnderlying(uint256 amountIn, address to)
        external
        whenNotPaused
        returns (uint256)
    {
        (
            address treasury,
            address underlying,
            uint256 amountOut
        ) = _prepareUnderlyingWithdrawal(amountIn);
        ITreasury(treasury).withdraw(underlying, amountOut, to);
        mintingStats.usdrToUnderlying += amountIn;
        return amountOut;
    }

    function swapFromTNGBL(
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) external whenNotPaused returns (uint256 amountOut) {
        (
            address treasury,
            address tngbl,
            address tngblOracle,
            address usdr
        ) = abi.decode(
                addressProvider.getAddresses(
                    abi.encode(
                        TREASURY_ADDRESS,
                        TNGBL_ADDRESS,
                        TNGBL_ORACLE_ADDRESS,
                        USDR_ADDRESS
                    )
                ),
                (address, address, address, address)
            );
        require(
            amountIn <= _maxTNGBLMintingAmount(tngblOracle),
            "amount too high"
        );
        IERC20(tngbl).safeTransferFrom(msg.sender, treasury, amountIn);
        uint256 quote = IPriceOracle(tngblOracle).quote(1e18);
        amountOut = _applyFee(quote * amountIn, depositFee) / 1e27;
        require(amountOut >= amountOutMin, "insufficient output amount");
        IUSDR(usdr).mint(to, amountOut);
        mintingStats.tngblToUSDR += amountOut;
    }

    function swapFromUnderlying(uint256 amountIn, address to)
        external
        whenNotPaused
        returns (uint256 amountOut)
    {
        (address treasury, address usdr, address underlying) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(TREASURY_ADDRESS, USDR_ADDRESS, UNDERLYING_ADDRESS)
            ),
            (address, address, address)
        );
        IERC20(underlying).safeTransferFrom(
            msg.sender,
            address(this),
            amountIn
        );
        IERC20(underlying).transfer(treasury, amountIn);
        amountOut = _applyFee(_scaleFromUnderlying(amountIn), depositFee);
        IUSDR(usdr).mint(to, amountOut);
        mintingStats.underlyingToUSDR += amountOut;
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function setAddressProvider(AddressProvider _addressProvider)
        public
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        AddressAccessor.setAddressProvider(_addressProvider);
        updateUnderlying();
    }

    function updateUnderlying() public onlyRole(DEFAULT_ADMIN_ROLE) {
        (address usdr, address underlying) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(USDR_ADDRESS, UNDERLYING_ADDRESS)
            ),
            (address, address)
        );
        uint8 usdrDecimals = ERC20(usdr).decimals();
        uint8 underlyingDecimals = ERC20(underlying).decimals();
        _scale = _computeScale(usdrDecimals, underlyingDecimals);
    }

    function _applyFee(uint256 amount, uint256 fee)
        private
        pure
        returns (uint256)
    {
        assembly {
            if iszero(iszero(fee)) {
                amount := sub(amount, div(mul(amount, fee), 10000))
            }
        }
        return amount;
    }

    function _computeScale(uint8 usdrDecimals, uint8 underlyingDecimals)
        private
        pure
        returns (uint256 scale)
    {
        assembly {
            switch lt(usdrDecimals, underlyingDecimals)
            case 0 {
                scale := shl(
                    128,
                    exp(10, sub(usdrDecimals, underlyingDecimals))
                )
            }
            default {
                scale := exp(10, sub(underlyingDecimals, usdrDecimals))
            }
        }
    }

    function _maxTNGBLMintingAmount(address tngblOracle)
        private
        view
        returns (uint256)
    {
        uint256 minted = mintingStats.underlyingToUSDR +
            mintingStats.usdrFromGains;
        uint256 redeemed = mintingStats.usdrToUnderlying +
            mintingStats.usdrToPromissory +
            mintingStats.usdrToTNGBL +
            10 *
            mintingStats.tngblToUSDR;
        if (redeemed >= minted) return 0;
        uint256 amount = ((minted - redeemed) * 1e26) /
            IPriceOracle(tngblOracle).quote(1e18);
        return amount < 1e16 ? 0 : amount;
    }

    function _prepareTNGBLWithdrawal(uint256 amountIn)
        private
        returns (
            address treasury,
            address tngbl,
            uint256 amountOut
        )
    {
        address usdr;
        address oracle;
        (treasury, usdr, tngbl, oracle) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(
                    TREASURY_ADDRESS,
                    USDR_ADDRESS,
                    TNGBL_ADDRESS,
                    TNGBL_ORACLE_ADDRESS
                )
            ),
            (address, address, address, address)
        );
        IUSDR(usdr).burn(msg.sender, amountIn);
        uint8 tngblDecimals = IERC20Metadata(tngbl).decimals();
        amountOut = _applyFee(
            _scaleAmount(amountIn, 9, tngblDecimals),
            withdrawalFee
        );
        ITreasury.TreasuryValue memory tv = ITreasury(treasury)
            .getTreasuryValue();
        require(
            tv.total - tv.tngbl - tv.tngblLiquidity.tngbl <
                _scaleAmount(amountOut, tngblDecimals, 18),
            "sufficient backing"
        ); // can withdraw underlying or pDAI
        uint256 tngblBalance = IERC20(tngbl).balanceOf(treasury);
        uint256 tngblPrice = IPriceOracle(oracle).quote(1e18);
        amountOut = (amountOut * (10**tngblDecimals)) / tngblPrice;
        require(tngblBalance >= amountOut, "insufficient backing");
    }

    function _preparePromissoryWithdrawal(uint256 amountIn)
        private
        returns (address promissory, uint256 amountOut)
    {
        address treasury;
        address usdr;
        (treasury, usdr, promissory) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(TREASURY_ADDRESS, USDR_ADDRESS, PROMISSORY_ADDRESS)
            ),
            (address, address, address)
        );
        IUSDR(usdr).burn(msg.sender, amountIn);
        uint8 promissoryDecimals = IERC20Metadata(promissory).decimals();
        amountOut = _applyFee(
            _scaleAmount(amountIn, 9, promissoryDecimals),
            withdrawalFee
        );
        ITreasury.TreasuryValue memory tv = ITreasury(treasury)
            .getTreasuryValue();
        require(
            tv.total - tv.tngbl - tv.tngblLiquidity.tngbl >=
                _scaleAmount(amountOut, promissoryDecimals, 18),
            "insufficient backing"
        );
    }

    function _prepareUnderlyingWithdrawal(uint256 amountIn)
        private
        returns (
            address treasury,
            address underlying,
            uint256 amountOut
        )
    {
        address usdr;
        (treasury, usdr, underlying) = abi.decode(
            addressProvider.getAddresses(
                abi.encode(TREASURY_ADDRESS, USDR_ADDRESS, UNDERLYING_ADDRESS)
            ),
            (address, address, address)
        );
        IUSDR(usdr).burn(msg.sender, amountIn);
        amountOut = _applyFee(_scaleToUnderlying(amountIn), withdrawalFee);
    }

    function _scaleAmount(
        uint256 amount,
        uint8 fromDecimals,
        uint8 toDecimals
    ) private pure returns (uint256) {
        assembly {
            switch lt(fromDecimals, toDecimals)
            case 0 {
                if gt(fromDecimals, toDecimals) {
                    amount := div(
                        amount,
                        exp(10, sub(fromDecimals, toDecimals))
                    )
                }
            }
            default {
                amount := mul(amount, exp(10, sub(toDecimals, fromDecimals)))
            }
        }
        return amount;
    }

    function _scaleFromUnderlying(uint256 amount)
        private
        view
        returns (uint256 result)
    {
        uint256 scale = _scale;
        assembly {
            switch scale
            case 0 {
                result := amount
            }
            default {
                switch gt(scale, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
                case 0 {
                    result := div(amount, scale)
                }
                default {
                    result := mul(amount, shr(128, scale))
                }
            }
        }
    }

    function _scaleToUnderlying(uint256 amount)
        private
        view
        returns (uint256 result)
    {
        uint256 scale = _scale;
        assembly {
            switch scale
            case 0 {
                result := amount
            }
            default {
                switch gt(scale, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
                case 0 {
                    result := mul(amount, scale)
                }
                default {
                    result := div(amount, shr(128, scale))
                }
            }
        }
    }
}
