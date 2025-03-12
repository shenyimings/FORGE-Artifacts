// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./OpenSkyCollateralHolderChecker.sol";
import "../../interfaces/IOpenSkyFlashClaimReceiver.sol";
import "./IApeCoinStaking.sol";

contract OpenSkyDepositBAYCHelper is IOpenSkyFlashClaimReceiver, ERC721Holder, OpenSkyCollateralHolderChecker {
    using SafeERC20 for IERC20;

    IApeCoinStaking public immutable apeCoinStaking;
    IERC20 public immutable apeCoin;

    constructor(
        address _apeCoinStakingContractAddress,
        address _apeCoinContractAddress,
        address _instantLoanCollateralHolder,
        address _bespokeLoanCollateralHolder
    ) OpenSkyCollateralHolderChecker(_instantLoanCollateralHolder, _bespokeLoanCollateralHolder) {
        apeCoinStaking = IApeCoinStaking(_apeCoinStakingContractAddress);
        apeCoin = IERC20(_apeCoinContractAddress);
    }

    function executeOperation(
        address[] calldata nftAddresses,
        uint256[] calldata tokenIds,
        address initiator,
        address operator,
        bytes calldata params
    ) external override onlyCollateralHolder returns (bool) {
        require(msg.sender == operator, "PARAMS_ERROR");

        (IApeCoinStaking.SingleNft[] memory baycs) = abi.decode(params, (IApeCoinStaking.SingleNft[]));

        uint256 amount;
        for (uint256 i; i < baycs.length; i++) {
            amount += baycs[i].amount;
        }

        apeCoin.safeTransferFrom(initiator, address(this), amount);
        apeCoin.safeApprove(address(apeCoinStaking), amount);

        apeCoinStaking.depositBAYC(baycs);

        for (uint256 i; i < nftAddresses.length; i++) {
            IERC721(nftAddresses[i]).approve(operator, tokenIds[i]);
        }
        return true;
    }
}
