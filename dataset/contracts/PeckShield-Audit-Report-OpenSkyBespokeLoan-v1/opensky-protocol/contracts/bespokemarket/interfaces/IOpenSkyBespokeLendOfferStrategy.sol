// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '../libraries/BespokeTypes.sol';

interface IOpenSkyBespokeLendOfferStrategy {
    function validate(BespokeTypes.Offer memory offerData, BespokeTypes.TakeLendInfoForStrategy memory takeInfo)
        external
        view;
}
