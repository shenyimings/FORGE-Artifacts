// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Vault Contract
 */
contract Vault is Ownable, ReentrancyGuard {
    using Address for address;
    using SafeERC20 for IERC20;

    /// @notice Event emitted only on construction.
    event VaultDeployed();

    /// @notice Event emitted when new teller added to vault.
    event NewTellerAdded(address newTeller, uint256 priority);

    /// @notice Event emitted when current priority changed.
    event TellerPriorityChanged(address teller, uint256 newPriority);

    /// @notice Event emitted when pay vidya token to provider.
    event ProviderPaid(address provider, uint256 vidyaAmount);

    /// @notice Event emitted when vidya token rate calculated.
    event VidyaRateCalculated(uint256 vidyaRate);

    IERC20 Vidya;

    mapping(address => bool) teller;
    mapping(address => uint256) tellerPriority;
    mapping(address => uint256) priorityFreeze;

    uint256 totalPriority;
    uint256 vidyaRate;
    uint256 timeToCalculateRate;

    modifier onlyTeller() {
        require(teller[msg.sender], "Vault: Caller is not the teller.");
        _;
    }

    /**
     * @dev Constructor function
     * @param _Vidya Interface of Vidya token => 0x3D3D35bb9bEC23b06Ca00fe472b50E7A4c692C30
     */
    constructor(IERC20 _Vidya) {
        Vidya = _Vidya;

        emit VaultDeployed();
    }

    /**
     * @dev External function to add the teller. This function can be called by only owner.
     * @param _teller Address of teller
     * @param _priority Priority of teller
     */
    function addTeller(address _teller, uint256 _priority) external onlyOwner {
        require(
            _teller.isContract() == true,
            "Vault: Address is not the contract address."
        );
        require(teller[_teller] == false, "Vault: Caller is a teller already.");
        require(_priority > 0, "Vault: Priority should be more than zero.");

        teller[_teller] = true;
        tellerPriority[_teller] = _priority;
        totalPriority += _priority;
        priorityFreeze[_teller] = block.timestamp + 7 days;

        emit NewTellerAdded(_teller, _priority);
    }

    /**
     * @dev External function to change the priority of teller. This function can be called by only owner.
     * @param _teller Address of teller
     * @param _newPriority New priority of teller
     */
    function changePriority(address _teller, uint256 _newPriority)
        external
        onlyOwner
    {
        require(
            _teller.isContract() == true,
            "Vault: Address is not the contract address."
        );
        require(teller[_teller], "Vault: Caller is not the teller.");
        require(_newPriority > 0, "Vault: Priority should be more than zero.");
        require(
            priorityFreeze[_teller] <= block.timestamp,
            "Vault: Not time to change the priority."
        );

        uint256 _oldPriority = tellerPriority[_teller];
        totalPriority = (totalPriority - _oldPriority) + _newPriority;
        tellerPriority[_teller] = _newPriority;

        priorityFreeze[_teller] = block.timestamp + 1 weeks;

        emit TellerPriorityChanged(_teller, _newPriority);
    }

    /**
     * @dev External function to pay the Vidya token to investors. This function can be called by only teller.
     * @param _provider Address of provider
     * @param _providerTimeWeight Weight time of provider
     * @param _totalWeight Sum of provider weight
     */
    function payProvider(
        address _provider,
        uint256 _providerTimeWeight,
        uint256 _totalWeight
    ) external onlyTeller {
        uint256 numerator = vidyaRate *
            _providerTimeWeight *
            tellerPriority[msg.sender];

        uint256 denominator = _totalWeight * totalPriority;

        uint256 amount = 0;
        if (denominator != 0) {
            amount = numerator / denominator;
        }

        if (timeToCalculateRate <= block.timestamp) {
            calculateRate();
        }

        Vidya.safeTransfer(_provider, amount);

        emit ProviderPaid(_provider, amount);
    }

    /**
     * @dev Private function to calculate the Vidya Rate.
     */
    function calculateRate() private {
        vidyaRate = Vidya.balanceOf(address(this)) / 26 weeks; // 6 months
        timeToCalculateRate = block.timestamp + 1 weeks;

        emit VidyaRateCalculated(vidyaRate);
    }

    /**
     * @dev External function to calculate the Vidya Rate.
     */
    function calculateRateExternal() external nonReentrant {
        require(
            timeToCalculateRate <= block.timestamp,
            "Vault: Not time to adjust."
        );
        calculateRate();
    }
}
