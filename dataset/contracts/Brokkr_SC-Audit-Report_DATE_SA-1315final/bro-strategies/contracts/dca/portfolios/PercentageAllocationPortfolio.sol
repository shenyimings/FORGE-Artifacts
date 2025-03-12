// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IDCAPortfolio } from "../interfaces/IDCAPortfolio.sol";
import { IDCAInvestable } from "../interfaces/IDCAInvestable.sol";
import { PortfolioAccessBaseUpgradeable } from "../base/PortfolioAccessBaseUpgradeable.sol";

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract PercentageAllocationPortfolio is
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    PortfolioAccessBaseUpgradeable,
    IDCAPortfolio
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public depositToken;

    Investable[] public investables;

    uint8 public investAmountSplit;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(DCAPortfolioInitArgs calldata portfolioArgs)
        external
        initializer
    {
        __UUPSUpgradeable_init();
        __PortfolioAccessBaseUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        for (uint256 i = 0; i < portfolioArgs.investables.length; i++) {
            if (
                portfolioArgs.investables[i].depositToken() !=
                portfolioArgs.depositToken
            ) {
                revert InvalidDepositToken();
            }

            if (portfolioArgs.investables[i].isEmergencyExited()) {
                revert InvestableIsEmergencyExited();
            }

            investables.push(Investable(portfolioArgs.investables[i], false));
        }

        depositToken = portfolioArgs.depositToken;
        investAmountSplit = portfolioArgs.investAmountSplit;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function deposit(uint256 amount, uint8) external nonReentrant {
        _deposit(_msgSender(), amount);
    }

    function depositFor(
        address sender,
        uint256 amount,
        uint8
    ) external onlyPortfolio nonReentrant {
        _deposit(sender, amount);
    }

    function _deposit(address sender, uint256 amount) private {
        uint256 activeInvestables = _checkActiveInvestables();
        if (activeInvestables == 0) {
            revert PortfolioIsEmergencyExited();
        }

        depositToken.safeTransferFrom(_msgSender(), address(this), amount);

        uint256 perInvestableDeposit = amount / activeInvestables;
        for (uint256 i = 0; i < investables.length; i++) {
            depositToken.safeApprove(
                address(investables[i].investable),
                perInvestableDeposit
            );

            investables[i].investable.depositFor(
                sender,
                perInvestableDeposit,
                investAmountSplit
            );
        }
    }

    function _checkActiveInvestables()
        private
        returns (uint256 activeInvestables)
    {
        for (uint256 i = 0; i < investables.length; i++) {
            if (investables[i].emergencyExited) {
                continue;
            }

            if (investables[i].investable.isEmergencyExited()) {
                investables[i].emergencyExited = true;
                continue;
            }

            activeInvestables++;
        }
    }

    function depositSelected(
        uint256 amount,
        uint256[] calldata selectedInvestables
    ) external nonReentrant {
        if (selectedInvestables.length > investables.length) {
            // solhint-disable-next-line
            revert(
                "Selected investables length is higher then actual investables"
            );
        }

        depositToken.safeTransferFrom(_msgSender(), address(this), amount);

        uint256 perInvestableDeposit = amount / selectedInvestables.length;
        for (uint256 i = 0; i < selectedInvestables.length; i++) {
            depositToken.safeApprove(
                address(investables[selectedInvestables[i]].investable),
                perInvestableDeposit
            );

            investables[selectedInvestables[i]].investable.depositFor(
                _msgSender(),
                perInvestableDeposit,
                investAmountSplit
            );
        }
    }

    function withdrawAll(bool convertBluechipIntoDepositAsset)
        external
        nonReentrant
    {
        _withdrawAll(_msgSender(), convertBluechipIntoDepositAsset);
    }

    function withdrawAllFor(
        address sender,
        bool convertBluechipIntoDepositAsset
    ) external onlyPortfolio nonReentrant {
        _withdrawAll(sender, convertBluechipIntoDepositAsset);
    }

    function _withdrawAll(address sender, bool convertBluechipIntoDepositAsset)
        private
    {
        for (uint256 i = 0; i < investables.length; i++) {
            investables[i].investable.withdrawAllFor(
                sender,
                convertBluechipIntoDepositAsset
            );
        }
    }

    function withdrawAll(
        uint256 positionIndex,
        bool convertBluechipIntoDepositAsset
    ) external nonReentrant {
        _withdrawAll(
            _msgSender(),
            positionIndex,
            convertBluechipIntoDepositAsset
        );
    }

    function withdrawAllFor(
        address sender,
        uint256 positionIndex,
        bool convertBluechipIntoDepositAsset
    ) external onlyPortfolio nonReentrant {
        _withdrawAll(sender, positionIndex, convertBluechipIntoDepositAsset);
    }

    function _withdrawAll(
        address sender,
        uint256 positionIndex,
        bool convertBluechipIntoDepositAsset
    ) private {
        for (uint256 i = 0; i < investables.length; i++) {
            investables[i].investable.withdrawAllFor(
                sender,
                positionIndex,
                convertBluechipIntoDepositAsset
            );
        }
    }

    function withdrawBluechip(bool convertBluechipIntoDepositAsset)
        external
        nonReentrant
    {
        _withdrawBluechip(_msgSender(), convertBluechipIntoDepositAsset);
    }

    function withdrawBluechipFor(
        address sender,
        bool convertBluechipIntoDepositAsset
    ) external onlyPortfolio nonReentrant {
        _withdrawBluechip(sender, convertBluechipIntoDepositAsset);
    }

    function _withdrawBluechip(
        address sender,
        bool convertBluechipIntoDepositAsset
    ) private {
        for (uint256 i = 0; i < investables.length; i++) {
            investables[i].investable.withdrawBluechipFor(
                sender,
                convertBluechipIntoDepositAsset
            );
        }
    }

    function withdrawBluechip(
        uint256 positionIndex,
        bool convertBluechipIntoDepositAsset
    ) external nonReentrant {
        _withdrawBluechip(
            _msgSender(),
            positionIndex,
            convertBluechipIntoDepositAsset
        );
    }

    function withdrawBluechipFor(
        address sender,
        uint256 positionIndex,
        bool convertBluechipIntoDepositAsset
    ) external onlyPortfolio nonReentrant {
        _withdrawBluechip(
            sender,
            positionIndex,
            convertBluechipIntoDepositAsset
        );
    }

    function _withdrawBluechip(
        address sender,
        uint256 positionIndex,
        bool convertBluechipIntoDepositAsset
    ) private {
        for (uint256 i = 0; i < investables.length; i++) {
            investables[i].investable.withdrawBluechipFor(
                sender,
                positionIndex,
                convertBluechipIntoDepositAsset
            );
        }
    }

    // ----- Base Class Setters -----
    function addDCAInvestable(IDCAInvestable newDCAInvestable)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < investables.length; i++) {
            if (investables[i].investable == newDCAInvestable) {
                revert DCAInvestableAlreadyAdded();
            }
        }

        if (newDCAInvestable.isEmergencyExited()) {
            revert InvestableIsEmergencyExited();
        }

        investables.push(Investable(newDCAInvestable, false));
    }

    // ----- Pausable -----
    function pause() external onlyOwner {
        super._pause();
    }

    function unpause() external onlyOwner {
        super._unpause();
    }

    function isEmergencyExited() external view returns (bool) {
        // portfolio should return true only if
        // all investables return true
        uint256 emergencyExitedInvestables = 0;
        for (uint256 i = 0; i < investables.length; i++) {
            if (investables[i].investable.isEmergencyExited()) {
                emergencyExitedInvestables++;
            }
        }

        return emergencyExitedInvestables == investables.length;
    }

    function equityValuation()
        external
        view
        returns (DCAEquityValuation[] memory)
    {
        uint256 totalValuationsLength;
        DCAEquityValuation[][]
            memory investableValuations = new DCAEquityValuation[][](
                investables.length
            );

        for (uint256 i = 0; i < investables.length; i++) {
            DCAEquityValuation[] memory investableValuation = investables[i]
                .investable
                .equityValuation();

            investableValuations[i] = investableValuation;
            totalValuationsLength += investableValuation.length;
        }

        DCAEquityValuation[] memory valuation = new DCAEquityValuation[](
            totalValuationsLength
        );
        uint256 current = 0;
        for (uint256 i = 0; i < investableValuations.length; i++) {
            for (uint256 j = 0; j < investableValuations[i].length; j++) {
                valuation[current] = investableValuations[i][j];
                current++;
            }
        }

        return valuation;
    }

    function minDepositAmount()
        external
        view
        returns (uint256 totalMinDepositAmount)
    {
        for (uint256 i = 0; i < investables.length; i++) {
            totalMinDepositAmount += investables[i]
                .investable
                .minDepositAmount();
        }
    }
}
