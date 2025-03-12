// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.16;

// interfaces
import {ICryptoSwap} from "./interfaces/ICryptoSwap.sol";
import {IMath} from "./interfaces/IMath.sol";
import {ICurveCryptoViews} from "./interfaces/ICurveCryptoViews.sol";

// libraries
import {LibMath} from "./lib/LibMath.sol";

contract CurveCryptoViews is ICurveCryptoViews {
    using LibMath for uint256;

    // constants
    uint256 private constant N_COINS = 2;
    uint256 private constant PRECISION = 10 ** 18; //* The precision to convert to

    /// @notice Curve Math Contract
    IMath public override math;

    constructor(address _math) {
        math = IMath(_math);
    }

    /// @notice Get the amount of coin j one would receive for swapping dx of coin i (excl. fees)
    /// @param cryptoSwap Curve Cryptoswap contract
    /// @param i Index of the coin to sell
    /// @param j Index of the coin to buy
    /// @param dx Amount to sell
    /// @return Amount of tokens to received + Any trading fees paid (in j)
    /// @dev solidity implementation of the get_dy excluding the last last line where fees are deducted
    /// @dev simplified version where we use that PRECISIONS = [1, 1]
    /// https://github.com/curvefi/curve-crypto-contract/blob/d7d04cd9ae038970e40be850df99de8c1ff7241b/contracts/tricrypto/CurveCryptoViews3.vy#L40-L78
    // slither-disable-next-line naming-convention
    function get_dy_no_fee_deduct(ICryptoSwap cryptoSwap, uint256 i, uint256 j, uint256 dx)
        public
        view
        override
        returns (uint256)
    {
        require(i != j && i < N_COINS && j < N_COINS, "coin index out of range");
        require(dx > 0, "do not exchange 0 coins");

        uint256 price_scale = cryptoSwap.price_scale();
        uint256[2] memory xp = [cryptoSwap.balances(0), cryptoSwap.balances(1)];

        uint256 A = cryptoSwap.A();
        uint256 gamma = cryptoSwap.gamma();
        uint256 D = cryptoSwap.D();

        if (cryptoSwap.future_A_gamma_time() > 0) {
            D = math.newton_D(A, gamma, [xp[0], (xp[1] * price_scale) / PRECISION]);
        }

        xp[i] += dx;
        xp = [xp[0], (xp[1] * price_scale) / PRECISION];

        uint256 y = math.newton_y(A, gamma, xp, D, j);
        uint256 dy = xp[j] - y - 1;
        xp[j] = y;
        if (j > 0) {
            dy = (dy * PRECISION) / price_scale;
        }
        return dy;
    }

    /* ******************* */
    /*  TEST / UI Helpers  */
    /* ******************* */

    /// @notice Get the amount of coin j one would have to pay as trading fees for swapping dx of coin i
    /// @param cryptoSwap Curve Cryptoswap contract
    /// @param i Index of the coin to sell
    /// @param j Index of the coin to buy
    /// @param dx Amount to sell
    /// @return Amount of token j paid as trading fees. 18 decimals
    // slither-disable-next-line naming-convention
    function get_dy_fees(ICryptoSwap cryptoSwap, uint256 i, uint256 j, uint256 dx)
        external
        view
        override
        returns (uint256)
    {
        uint256 dy_ex_fees = get_dy_no_fee_deduct(cryptoSwap, i, j, dx);
        uint256 dy = cryptoSwap.get_dy(i, j, dx);
        return dy_ex_fees - dy;
    }

    /// @notice Get the share of coin j one would have to pay as trading fees for swapping dx of coin i
    /// @param cryptoSwap Curve Cryptoswap contract
    /// @param i Index of the coin to sell
    /// @param j Index of the coin to buy
    /// @param dx Amount to sell
    /// @return Share of token j paid as trading fees. 18 decimals
    // slither-disable-next-line naming-convention
    function get_dy_fees_perc(ICryptoSwap cryptoSwap, uint256 i, uint256 j, uint256 dx)
        external
        view
        override
        returns (uint256)
    {
        uint256 dy_ex_fees = get_dy_no_fee_deduct(cryptoSwap, i, j, dx);
        uint256 dy = cryptoSwap.get_dy(i, j, dx);
        uint256 feesPayed = dy_ex_fees - dy;
        return feesPayed.wadDiv(dy_ex_fees);
    }

    /// @notice Get the amount of coin j one would receive for swapping dx of coin i
    /// @param cryptoSwap Curve Cryptoswap contract
    /// @param i Index of the coin to sell
    /// @param j Index of the coin to buy
    /// @param dx Amount to sell
    /// @return Amount of tokens to received (in j)
    /// @dev solidity wrapper around CryptoSwap's get_dy
    // slither-disable-next-line naming-convention
    function get_dy(ICryptoSwap cryptoSwap, uint256 i, uint256 j, uint256 dx)
        external
        view
        override
        returns (uint256)
    {
        return cryptoSwap.get_dy(i, j, dx);
    }

    /// @notice Get the amount of coin i one would have to pay for receiving dy of coin j (before any trading fees are charged)
    /// @dev Does not get the identical estimate (i.e. get_dy(get_dx(100))) ~= 100)
    ///      Question: Why is that the case? Answer: Newton_y stops when the converge limit is reached:
    ///      https://github.com/curvefi/curve-crypto-contract/blob/d7d04cd9ae038970e40be850df99de8c1ff7241b/contracts/two/CurveCryptoSwap2.vy#L355
    /// @dev Should be used for external contracts to get a fairly precise "estimate" of the amount of tokens one has to pay to receive dy tokens
    /// @dev simplified version where we use that PRECISIONS = [1, 1]
    /// @param cryptoSwap Curve Cryptoswap contract
    /// @param i Index of the coin to sell
    /// @param j Index of the coin to buy
    /// @param dy Amount to tokens to receive
    /// @return Amount of tokens to sell
    // slither-disable-next-line naming-convention
    function get_dx_ex_fees(ICryptoSwap cryptoSwap, uint256 i, uint256 j, uint256 dy)
        external
        view
        override
        returns (uint256)
    {
        require(i != j && i < N_COINS && j < N_COINS, "coin index out of range");
        require(dy > 0, "do not exchange 0 coins");

        uint256 price_scale = cryptoSwap.price_scale();
        uint256[2] memory xp = [cryptoSwap.balances(0), cryptoSwap.balances(1)];

        uint256 A = cryptoSwap.A();
        uint256 gamma = cryptoSwap.gamma();
        uint256 D = cryptoSwap.D();

        if (cryptoSwap.future_A_gamma_time() > 0) {
            D = math.newton_D(A, gamma, [xp[0], (xp[1] * price_scale) / PRECISION]);
        }

        xp[j] -= dy;
        xp = [xp[0], (xp[1] * price_scale) / PRECISION];

        uint256 x = math.newton_y(A, gamma, xp, D, i);
        uint256 dx = x - xp[i] + 1;
        xp[i] = x;
        if (i > 0) {
            dx = (dx * PRECISION) / price_scale;
        }

        return dx;
    }
}
