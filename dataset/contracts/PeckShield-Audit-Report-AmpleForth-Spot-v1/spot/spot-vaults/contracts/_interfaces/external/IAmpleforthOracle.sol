// SPDX-License-Identifier: GPL-3.0-or-later
// solhint-disable-next-line compiler-version
interface IAmpleforthOracle {
    // solhint-disable-next-line func-name-mixedcase
    function DECIMALS() external returns (uint8);
    function getData() external returns (uint256, bool);
}
