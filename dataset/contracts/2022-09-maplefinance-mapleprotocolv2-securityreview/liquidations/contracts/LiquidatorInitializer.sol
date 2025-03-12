// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { LiquidatorStorage } from "./LiquidatorStorage.sol";

contract LiquidatorInitializer is LiquidatorStorage {

    function decodeArguments(bytes calldata calldata_) public pure returns (address loanManager_, address collateralAsset_, address fundsAsset_) {
        ( loanManager_, collateralAsset_, fundsAsset_ ) = abi.decode(calldata_, (address, address, address));
    }

    function encodeArguments(address loanManager_, address collateralAsset_, address fundsAsset_) external pure returns (bytes memory calldata_) {
        calldata_ = abi.encode(loanManager_, collateralAsset_, fundsAsset_);
    }

    fallback() external {
        ( address loanManager_, address collateralAsset_, address fundsAsset_ ) = decodeArguments(msg.data);

        _initialize(loanManager_, collateralAsset_, fundsAsset_);
    }

    function _initialize(address loanManager_, address collateralAsset_, address fundsAsset_) internal {
        require(loanManager_ != address(0), "LIQI:I:ZERO_LM");

        loanManager     = loanManager_;
        collateralAsset = collateralAsset_;
        fundsAsset      = fundsAsset_;
        locked          = 1;
    }

}
