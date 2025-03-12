// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IVault.sol";

/**
 * @title Dev Teller Contract
 */
contract DevTeller is Ownable, ReentrancyGuard {
    using Address for address;

    /// @notice Event emitted only on construction.
    event DevTellerDeployed();

    /// @notice Event emitted when teller toggled.
    event TellerToggled(address teller, bool status);

    /// @notice Event emitted when provider claimed.
    event Claimed(address provider, bool success);

    /// @notice Event emitted when a new developer is added.
    event newDeveloperAdded(address developer);

    /// @notice Event emitted when a developer is removed.
    event devRemoved(address developer);

    /// @notice Event emitted when weight of developer is changed.
    event weightChanged(address developer, uint256 weight);

    IVault Vault;

    struct Developer {
        uint256 weight;
        uint256 lastClaim;
        bool isDeveloper;
    }

    mapping(address => Developer) developers;
    uint256 totalWeight;
    uint256 tellerClosedTime;

    bool devTellerOpen;

    modifier isDevTellerOpen() {
        require(devTellerOpen, "DevTeller: DevTeller is not opened.");
        _;
    }

    modifier onlyDeveloper() {
        require(
            developers[msg.sender].isDeveloper,
            "DevTeller: Caller is not a developer."
        );
        _;
    }

    /**
     * @dev Constructor function
     * @param _Vault Interface of Vault
     */
    constructor(IVault _Vault) {
        Vault = _Vault;

        emit DevTellerDeployed();
    }

    /**
     * @dev External function to toggle the teller. This function can be called by only owner.
     */
    function toggleTeller() external onlyOwner {
        if (!(devTellerOpen = !devTellerOpen)) {
            tellerClosedTime = block.timestamp;
        }

        emit TellerToggled(address(this), devTellerOpen);
    }

    /**
     * @dev External function to add the developer. This function can be called by only owner.
     * @param _dev Developer Address
     * @param _weight Developer Weight
     */
    function addDeveloper(address _dev, uint256 _weight)
        external
        onlyOwner
        isDevTellerOpen
    {
        require(
            !developers[_dev].isDeveloper,
            "DevTeller: Already a developer"
        );

        developers[_dev].weight = _weight;
        developers[_dev].lastClaim = block.timestamp;
        developers[_dev].isDeveloper = true;
        totalWeight += _weight;

        emit newDeveloperAdded(_dev);
    }

    /**
     * @dev External function to change the weight of developer. This function can be called by only owner.
     * @param _dev Developer Address
     * @param _weight Developer Weight
     * @param _isAdd If true, add the weight of dev else subtract the weight of dev.
     */
    function changeDeveloperWeight(
        address _dev,
        uint256 _weight,
        bool _isAdd
    ) external onlyOwner {
        require(
            developers[_dev].isDeveloper,
            "DevTeller: Not currently a developer"
        );
        Developer storage dev = developers[_dev];
        claim(_dev);
        if (_isAdd) {
            dev.weight += _weight;
            totalWeight += _weight;
        } else {
            if (dev.weight > _weight) {
                dev.weight -= _weight;
                totalWeight -= _weight;
            } else {
                totalWeight -= dev.weight;
                dev.weight = 0;
                dev.isDeveloper = false;
                emit devRemoved(_dev);
            }
        }
        emit weightChanged(_dev, developers[_dev].weight);
    }

    /**
     * @dev External function to remove the developer. This function can be called by only owner.
     * @param _dev Developer Address
     */
    function removeDeveloper(address _dev) external onlyOwner {
        require(
            developers[_dev].isDeveloper,
            "DevTeller: Not currently a developer"
        );
        claim(_dev);
        Developer memory dev = developers[_dev];
        totalWeight -= dev.weight;

        delete developers[_dev];

        emit devRemoved(_dev);
    }

    /**
     * @dev Private function to claim the vidya token.
     * @param _dev Developer Address
     */
    function claim(address _dev) private {
        Developer storage dev = developers[_dev];

        uint256 timeGap = block.timestamp - dev.lastClaim;

        if (!devTellerOpen) {
            timeGap = tellerClosedTime - dev.lastClaim;
        }

        uint256 timeWeight = timeGap * dev.weight;

        dev.lastClaim = block.timestamp;

        Vault.payProvider(_dev, timeWeight, totalWeight);

        emit Claimed(_dev, true);
    }

    /**
     * @dev External function to claim the vidya token. This function can be called by only developer and teller must be opened.
     */
    function externalClaim()
        external
        onlyDeveloper
        nonReentrant
        isDevTellerOpen
    {
        claim(msg.sender);
    }
}
