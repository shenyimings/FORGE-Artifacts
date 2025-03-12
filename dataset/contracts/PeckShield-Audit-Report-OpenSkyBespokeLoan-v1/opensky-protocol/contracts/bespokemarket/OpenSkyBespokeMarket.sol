// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

import './libraries/BespokeTypes.sol';
import './libraries/BespokeLogic.sol';
import './libraries/TakeLendOfferLogic.sol';
import './libraries/TakeBorrowOfferLogic.sol';
import './libraries/RepayLogic.sol';
import './libraries/ForecloseLogic.sol';

import '../interfaces/IOpenSkySettings.sol';
import '../interfaces/IACLManager.sol';
import './interfaces/IOpenSkyBespokeSettings.sol';
import './interfaces/IOpenSkyBespokeMarket.sol';

/**
 * @title OpenSkyBespokeMarket contract
 * @author OpenSky Labs
 * @notice Main point of interaction with OpenSky protocol's bespoke market
 * - Users can:
 *   # takeBorrowOffer
 *   # takeLendOffer
 *   # repay
 *   # foreclose
 **/
contract OpenSkyBespokeMarket is Context, Pausable, ReentrancyGuard, IOpenSkyBespokeMarket {
    using SafeERC20 for IERC20;

    IOpenSkySettings public immutable SETTINGS;
    IOpenSkyBespokeSettings public immutable BESPOKE_SETTINGS;

    mapping(address => uint256) public minNonce;
    mapping(address => mapping(uint256 => BespokeTypes.NonceInfo)) public _nonce;

    BespokeTypes.Counter private _loanIdTracker;

    mapping(uint256 => BespokeTypes.LoanData) internal _loans;

    constructor(address SETTINGS_, address BESPOKE_SETTINGS_) Pausable() ReentrancyGuard() {
        SETTINGS = IOpenSkySettings(SETTINGS_);
        BESPOKE_SETTINGS = IOpenSkyBespokeSettings(BESPOKE_SETTINGS_);
    }

    /// @dev Only emergency admin can call functions marked by this modifier.
    modifier onlyEmergencyAdmin() {
        IACLManager ACLManager = IACLManager(SETTINGS.ACLManagerAddress());
        require(ACLManager.isEmergencyAdmin(_msgSender()), 'BM_ACL_ONLY_EMERGENCY_ADMIN_CAN_CALL');
        _;
    }

    modifier onlyAirdropOperator() {
        IACLManager ACLManager = IACLManager(SETTINGS.ACLManagerAddress());
        require(ACLManager.isAirdropOperator(_msgSender()), 'BM_ACL_ONLY_AIRDROP_OPERATOR_CAN_CALL');
        _;
    }

    modifier checkLoanExists(uint256 loanId) {
        require(_loans[loanId].amount > 0 && _loans[loanId].tokenAddress != address(0), 'BM_CHECK_LOAN_NOT_EXISTS');
        _;
    }

    /// @dev Pause pool for emergency case, can only be called by emergency admin.
    function pause() external onlyEmergencyAdmin {
        _pause();
    }

    /// @dev Unpause pool for emergency case, can only be called by emergency admin.
    function unpause() external onlyEmergencyAdmin {
        _unpause();
    }

    /// @notice Cancel all pending offers for a sender
    /// @param minNonce_ minimum user nonce
    function cancelAllBorrowOffersForSender(uint256 minNonce_) external {
        require(minNonce_ > minNonce[msg.sender], 'BM_CANCEL_NONCE_LOWER_THAN_CURRENT');
        require(minNonce_ < minNonce[msg.sender] + 500000, 'BM_CANCEL_CANNOT_CANCEL_MORE');
        minNonce[msg.sender] = minNonce_;

        emit CancelAllOffers(msg.sender, minNonce_);
    }

    /// @param offerNonces array of borrowOffer nonces
    function cancelMultipleBorrowOffers(uint256[] calldata offerNonces) external {
        require(offerNonces.length > 0, 'BM_CANCEL_CANNOT_BE_EMPTY');

        for (uint256 i = 0; i < offerNonces.length; i++) {
            require(offerNonces[i] >= minNonce[msg.sender], 'BM_CANCEL_NONCE_LOWER_THAN_CURRENT');
            _nonce[msg.sender][offerNonces[i]].invalid = true;
        }

        emit CancelMultipleOffers(msg.sender, offerNonces);
    }

    function isValidNonce(address account, uint256 nonce) external view returns (bool) {
        return !_nonce[account][nonce].invalid && nonce >= minNonce[account];
    }

    /// @notice take an borrowing offer using ERC20 include ERC20
    function takeBorrowOffer(
        BespokeTypes.Offer memory offerData,
        uint256 supplyAmount,
        uint256 supplyDuration,
        address lendAsset,
        bool autoConvertWhenRepay //Only make sence when lend asset is different with borrow asset. eg. oToken,aToken etc.
    ) public override whenNotPaused nonReentrant returns (uint256) {
        return
            TakeBorrowOfferLogic.executeTakeBorrowOffer(
                _nonce,
                minNonce,
                _loans,
                _loanIdTracker,
                offerData,
                BespokeTypes.TakeBorrowInfo({
                    borrowAmount: supplyAmount,
                    borrowDuration: supplyDuration,
                    lendAsset: lendAsset,
                    autoConvertWhenRepay: autoConvertWhenRepay
                }),
                BESPOKE_SETTINGS
            );
    }

    function takeLendOffer(
        BespokeTypes.Offer memory offerData,
        uint256 tokenId,
        uint256 borrowAmount,
        uint256 borrowDuration,
        address onBehalfOf,
        bytes memory params
    ) public override whenNotPaused nonReentrant returns (uint256) {
        return
            TakeLendOfferLogic.executeTakeLendOffer(
                _nonce,
                minNonce,
                _loans,
                _loanIdTracker,
                offerData,
                BespokeTypes.TakeLendInfo({
                    borrowAmount: borrowAmount,
                    borrowDuration: borrowDuration,
                    tokenId: tokenId,
                    onBehalfOf: onBehalfOf,
                    params: params
                }),
                BESPOKE_SETTINGS
            );
    }

    /// @notice Anyone can repay but only OpenSkyBorrowNFT owner receive collaterial
    /// @notice Only OpenSkyLendNFT owner can recieve the payment
    /// @notice This function is not pausable for safety
    function repay(uint256 loanId) public override nonReentrant checkLoanExists(loanId) {
        RepayLogic.repay(_loans, loanId, BESPOKE_SETTINGS, SETTINGS);
    }

    /// @notice anyone can trigger but only OpenSkyLendNFT owner can receive collaterial
    function foreclose(uint256 loanId) public override whenNotPaused nonReentrant checkLoanExists(loanId) {
        ForecloseLogic.foreclose(_loans, loanId, BESPOKE_SETTINGS);
    }

    function getLoanData(uint256 loanId) public view override returns (BespokeTypes.LoanData memory) {
        return BespokeLogic.getLoanDataWithStatus(_loans[loanId]);
    }

    function getStatus(uint256 loanId) public view override returns (BespokeTypes.LoanStatus) {
        return BespokeLogic.getLoanStatus(_loans[loanId]);
    }

    function getBorrowInterest(uint256 loanId) public view override returns (uint256) {
        return BespokeLogic.getBorrowInterest(_loans[loanId]);
    }

    // @dev principal + interest
    function getBorrowBalance(uint256 loanId) public view override returns (uint256) {
        return BespokeLogic.getBorrowBalance(_loans[loanId]);
    }

    function getPenalty(uint256 loanId) public view override returns (uint256) {
        return BespokeLogic.getPenalty(_loans[loanId]);
    }

    /// @dev transfer ERC20 from the utility contract, for ERC20 recovery in case of stuck tokens due
    /// direct transfers to the contract address.
    /// @param token token to transfer
    /// @param to recipient of the transfer
    /// @param amount amount to send
    function emergencyTokenTransfer(
        address token,
        address to,
        uint256 amount
    ) external onlyEmergencyAdmin {
        IERC20(token).safeTransfer(to, amount);
    }

    receive() external payable {
        revert('BM_RECEIVE_NOT_ALLOWED');
    }

    fallback() external payable {
        revert('BM_FALLBACK_NOT_ALLOWED');
    }
}
