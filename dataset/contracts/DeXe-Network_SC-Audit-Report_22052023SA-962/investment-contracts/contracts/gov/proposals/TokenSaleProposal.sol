// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";

import "@solarity/solidity-lib/contracts-registry/AbstractDependant.sol";

import "../../interfaces/gov/proposals/ITokenSaleProposal.sol";
import "../../interfaces/core/ISBT721.sol";

import "../../libs/gov/token-sale-proposal/TokenSaleProposalCreate.sol";
import "../../libs/gov/token-sale-proposal/TokenSaleProposalBuy.sol";
import "../../libs/gov/token-sale-proposal/TokenSaleProposalVesting.sol";
import "../../libs/gov/token-sale-proposal/TokenSaleProposalWhitelist.sol";
import "../../libs/gov/token-sale-proposal/TokenSaleProposalClaim.sol";
import "../../libs/gov/token-sale-proposal/TokenSaleProposalRecover.sol";

contract TokenSaleProposal is
    ITokenSaleProposal,
    ERC721HolderUpgradeable,
    ERC1155SupplyUpgradeable,
    AbstractDependant,
    Multicall
{
    using TokenSaleProposalCreate for *;
    using TokenSaleProposalBuy for Tier;
    using TokenSaleProposalVesting for Tier;
    using TokenSaleProposalWhitelist for Tier;
    using TokenSaleProposalClaim for Tier;
    using TokenSaleProposalRecover for Tier;

    address public govAddress;
    ISBT721 public babt;

    address public dexeGovAddress;
    CoreProperties public coreProperties;

    uint256 public override latestTierId;

    mapping(uint256 => Tier) internal _tiers;

    event TierCreated(
        uint256 tierId,
        address saleToken,
        ParticipationDetails[] participationDetails
    );
    event TierModified(
        uint256 tierId,
        address saleToken,
        ParticipationDetails[] participationDetails
    );
    event Bought(uint256 tierId, address paidWith, uint256 received, uint256 given, address buyer);
    event Whitelisted(uint256 tierId, address user);

    modifier onlyGov() {
        _onlyGov();
        _;
    }

    modifier onlyThis() {
        _onlyThis();
        _;
    }

    function __TokenSaleProposal_init(address _govAddress) external initializer {
        govAddress = _govAddress;
    }

    function setDependencies(
        address contractsRegistry,
        bytes memory
    ) public virtual override dependant {
        IContractsRegistry registry = IContractsRegistry(contractsRegistry);

        babt = ISBT721(registry.getBABTContract());
        dexeGovAddress = registry.getTreasuryContract();
        coreProperties = CoreProperties(registry.getCorePropertiesContract());
    }

    function createTiers(TierInitParams[] calldata tierInitParams) external override onlyGov {
        uint256 newTierId = latestTierId;

        latestTierId += tierInitParams.length;

        for (uint256 i = 0; i < tierInitParams.length; i++) {
            ++newTierId;

            _tiers.createTier(newTierId, tierInitParams[i]);

            emit TierCreated(
                newTierId,
                tierInitParams[i].saleTokenAddress,
                tierInitParams[i].participationDetails
            );
        }
    }

    function modifyTier(
        uint256 tierId,
        ITokenSaleProposal.TierInitParams calldata newSettings
    ) external onlyGov {
        _getActiveTier(tierId).modifyTier(newSettings);

        emit TierModified(tierId, newSettings.saleTokenAddress, newSettings.participationDetails);
    }

    function changeParticipationDetails(
        uint256 tierId,
        ITokenSaleProposal.ParticipationDetails[] calldata newSettings
    ) external onlyGov {
        ITokenSaleProposal.Tier storage tier = _getActiveTier(tierId);
        tier.changeParticipationDetails(newSettings);

        emit TierModified(tierId, tier.tierInitParams.saleTokenAddress, newSettings);
    }

    function addToWhitelist(WhitelistingRequest[] calldata requests) external override onlyGov {
        for (uint256 i = 0; i < requests.length; i++) {
            _getActiveTier(requests[i].tierId).addToWhitelist(requests[i]);
        }
    }

    function offTiers(uint256[] calldata tierIds) external override onlyGov {
        for (uint256 i = 0; i < tierIds.length; i++) {
            _getActiveTier(tierIds[i]).tierInfo.isOff = true;
        }
    }

    function recover(uint256[] calldata tierIds) external onlyGov {
        for (uint256 i = 0; i < tierIds.length; i++) {
            _getTier(tierIds[i]).recover();
        }
    }

    function claim(uint256[] calldata tierIds) external override {
        for (uint256 i = 0; i < tierIds.length; i++) {
            _getTier(tierIds[i]).claim();
        }
    }

    function vestingWithdraw(uint256[] calldata tierIds) external override {
        for (uint256 i = 0; i < tierIds.length; i++) {
            _getTier(tierIds[i]).vestingWithdraw();
        }
    }

    function buy(
        uint256 tierId,
        address tokenToBuyWith,
        uint256 amount,
        bytes32[] calldata proof
    ) external payable {
        uint256 bought = _getActiveTier(tierId).buy(tierId, tokenToBuyWith, amount, proof);

        emit Bought(tierId, tokenToBuyWith, bought, amount, msg.sender);
    }

    function lockParticipationTokens(
        uint256 tierId,
        address tokenToLock,
        uint256 amountToLock
    ) external payable override {
        _getActiveTier(tierId).lockParticipationTokens(tokenToLock, amountToLock);
    }

    function lockParticipationNft(
        uint256 tierId,
        address nftToLock,
        uint256[] calldata nftIdsToLock
    ) external override {
        _getActiveTier(tierId).lockParticipationNft(nftToLock, nftIdsToLock);
    }

    function unlockParticipationTokens(
        uint256 tierId,
        address tokenToUnlock,
        uint256 amountToUnlock
    ) external override {
        _getTier(tierId).unlockParticipationTokens(tokenToUnlock, amountToUnlock);
    }

    function unlockParticipationNft(
        uint256 tierId,
        address nftToUnlock,
        uint256[] calldata nftIdsToUnlock
    ) external override {
        _getTier(tierId).unlockParticipationNft(nftToUnlock, nftIdsToUnlock);
    }

    function mint(address user, uint256 tierId) external onlyThis {
        _mint(user, tierId, 1, "");

        emit Whitelisted(tierId, user);
    }

    function getSaleTokenAmount(
        address user,
        uint256 tierId,
        address tokenToBuyWith,
        uint256 amount,
        bytes32[] calldata proof
    ) external view returns (uint256) {
        return
            _getActiveTier(tierId).getSaleTokenAmount(user, tierId, tokenToBuyWith, amount, proof);
    }

    function getClaimAmounts(
        address user,
        uint256[] calldata tierIds
    ) external view returns (uint256[] memory claimAmounts) {
        claimAmounts = new uint256[](tierIds.length);

        for (uint256 i = 0; i < tierIds.length; i++) {
            claimAmounts[i] = _getTier(tierIds[i]).getClaimAmount(user);
        }
    }

    function getVestingWithdrawAmounts(
        address user,
        uint256[] calldata tierIds
    ) external view returns (uint256[] memory vestingWithdrawAmounts) {
        vestingWithdrawAmounts = new uint256[](tierIds.length);

        for (uint256 i = 0; i < tierIds.length; i++) {
            vestingWithdrawAmounts[i] = _getTier(tierIds[i]).getVestingWithdrawAmount(user);
        }
    }

    function getRecoverAmounts(
        uint256[] calldata tierIds
    ) external view returns (uint256[] memory recoveringAmounts) {
        recoveringAmounts = new uint256[](tierIds.length);

        for (uint256 i = 0; i < recoveringAmounts.length; i++) {
            recoveringAmounts[i] = _getTier(tierIds[i]).getRecoverAmount();
        }
    }

    function getTierViews(
        uint256 offset,
        uint256 limit
    ) external view returns (TierView[] memory tierViews) {
        return _tiers.getTierViews(offset, limit);
    }

    function getParticipationDetails(
        uint256 tierId
    ) external view returns (ITokenSaleProposal.ParticipationInfoView memory) {
        return _getActiveTier(tierId).getParticipationDetails();
    }

    function getUserViews(
        address user,
        uint256[] calldata tierIds,
        bytes32[][] calldata proofs
    ) external view returns (UserView[] memory userViews) {
        userViews = new UserView[](tierIds.length);

        for (uint256 i = 0; i < userViews.length; i++) {
            Tier storage tier = _getTier(tierIds[i]);

            userViews[i] = UserView({
                canParticipate: tier.canParticipate(tierIds[i], user, proofs[i]),
                purchaseView: tier.getPurchaseView(user),
                vestingUserView: tier.getVestingUserView(user)
            });
        }
    }

    function uri(uint256 tierId) public view override returns (string memory) {
        return _tiers[tierId].tierInfo.uri;
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        require(from == address(0), "TSP: only for minting");

        for (uint256 i = 0; i < ids.length; i++) {
            require(balanceOf(to, ids[i]) == 0, "TSP: balance can be only 0 or 1");
        }
    }

    function _onlyGov() internal view {
        require(msg.sender == govAddress, "TSP: not a Gov contract");
    }

    function _onlyThis() internal view {
        require(address(this) == msg.sender, "TSP: not this contract");
    }

    function _getTier(uint256 tierId) private view returns (Tier storage tier) {
        tier = _tiers[tierId];

        require(tier.tierInitParams.saleTokenAddress != address(0), "TSP: tier does not exist");
    }

    function _getActiveTier(uint256 tierId) private view returns (Tier storage tier) {
        tier = _getTier(tierId);

        require(!_tiers[tierId].tierInfo.isOff, "TSP: tier is off");
    }
}
