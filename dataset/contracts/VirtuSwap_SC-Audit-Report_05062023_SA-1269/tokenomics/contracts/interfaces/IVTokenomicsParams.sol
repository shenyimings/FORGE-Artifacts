// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {SD59x18} from "@prb/math/src/SD59x18.sol";

/**
@title IVTokenomicsParams
@dev Interface for the tokenomics parameters.

To learn more about these parameters
you can refer to Virtuswap Tokenomics Whitepaper.

*/
interface IVTokenomicsParams {
    /**
     * @dev Emitted when the tokenomics parameters are updated.
     */
    event UpdateTokenomicsParams(
        SD59x18 r,
        SD59x18 b,
        SD59x18 alpha,
        SD59x18 beta,
        SD59x18 gamma
    );

    /**
     * @dev Emitted when the lpBaseShare and lpBaseShareFactor are updated.
     */
    event UpdateLpBaseRewardsShare(
        SD59x18 lpBaseRewardsShare,
        SD59x18 lpBaseRewardsShareFactor
    );

    /**
     * @dev Allows the owner to update the tokenomics parameters.
     */
    function updateParams(
        SD59x18 _r,
        SD59x18 _b,
        SD59x18 _alpha,
        SD59x18 _beta,
        SD59x18 _gamma
    ) external;

    /**
     * @dev Allows the owner to update the lp base rewards share parameters.
     */
    function updateLpBaseRewardsShare(
        SD59x18 _lpBaseRewardsShare,
        SD59x18 _lpBaseRewardsShareFactor
    ) external;

    function r() external view returns (SD59x18);

    function b() external view returns (SD59x18);

    function alpha() external view returns (SD59x18);

    function beta() external view returns (SD59x18);

    function gamma() external view returns (SD59x18);

    function lpBaseRewardsShare() external view returns (SD59x18);

    function lpBaseRewardsShareFactor() external view returns (SD59x18);
}
