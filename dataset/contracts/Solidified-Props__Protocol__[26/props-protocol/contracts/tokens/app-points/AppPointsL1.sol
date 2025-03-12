// SPDX-License-Identifier: MIT

pragma solidity 0.7.3;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import "./AppPointsCommon.sol";

/**
 * @title  AppPointsL1
 * @author Props
 * @dev    The L1 version of AppPoints tokens. Each app in the Props protocol will
 *         get an associated AppPoints contract. AppPoints are ERC20 compatible and
 *         mintable according to an inflation rate.
 */
contract AppPointsL1 is Initializable, AppPointsCommon {
    using SafeMathUpgradeable for uint256;

    /**************************************
                     FIELDS
    ***************************************/

    // The Props protocol treasury address
    address public propsTreasury;

    // The percentage of each mint that goes to the Props treasury (denoted in ppm)
    uint256 public propsTreasuryMintPercentage;
    // The delay before a newly set inflation rate goes into effect
    uint256 public inflationRateChangeDelay;
    // The inflation rate of the app points token
    uint256 public inflationRate;
    // The new inflation rate that will go into effect once the delay passes
    uint256 public pendingInflationRate;

    // Time most recent mint occured at
    uint256 public lastMint;
    // Time most recent inflation rate change occured at
    uint256 public lastInflationRateChange;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 public DOMAIN_SEPARATOR_L1;

    /**************************************
                     EVENTS
    ***************************************/

    event InflationRateChanged(uint256 inflationRate);

    /***************************************
                   INITIALIZER
    ****************************************/

    /**
     * @dev Initializer.
     * @param _name The name of the app points token
     * @param _symbol The symbol of the app points token
     * @param _amount Initial amount of app points to mint
     * @param _owner The owner of the app points token
     * @param _propsTreasury The Props protocol treasury
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _amount,
        address _owner,
        address _propsTreasury
    ) public initializer {
        AppPointsCommon.__AppPointsCommon_init(_name, _symbol);

        DOMAIN_SEPARATOR_L1 = keccak256(
            abi.encode(
                // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
                0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                keccak256(bytes(name())),
                keccak256(bytes("1")),
                _getChainId(),
                address(this)
            )
        );

        propsTreasury = _propsTreasury;
        propsTreasuryMintPercentage = 50000; // 5%
        inflationRateChangeDelay = 7 days;

        // Initial mint
        _mintAppPoints(_owner, _amount);
    }

    /***************************************
                  OWNER ACTIONS
    ****************************************/

    /**
     * @dev Mint additional tokens according to the current inflation rate.
     *      The amount of tokens to get minted is determined by both the last
     *      mint time and the inflation rate (given by the following formula:
     *      (`currentTime` - `lastMintTime`) * `inflationRate`).
     */
    function mint() external onlyOwner {
        // If the delay for the new inflation rate passed, update the inflation rate
        if (block.timestamp.sub(lastInflationRateChange) > inflationRateChangeDelay) {
            inflationRate = pendingInflationRate;
        }

        // Should we revert on attempts to mint 0 additional AppPoints tokens?
        uint256 amount = inflationRate.mul(block.timestamp.sub(lastMint));
        if (amount != 0) {
            _mintAppPoints(owner(), amount);
        }
    }

    /**
     * @dev Set a new inflation rate. Once a new inflation rate is set, it
     *      takes some time before it goes into effect (the delay is determined
     *      by `inflationRateChangeDelay`).
     * @param _inflationRate The new inflation rate
     */
    function changeInflationRate(uint256 _inflationRate) external onlyOwner {
        pendingInflationRate = _inflationRate;
        lastInflationRateChange = block.timestamp;

        emit InflationRateChanged(pendingInflationRate);
    }

    /***************************************
               PERMIT VERIFICATION
    ****************************************/

    function verifyPermitSignature(
        address _owner,
        address _spender,
        uint256 _amount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) internal view override returns (bool) {
        return _verify(DOMAIN_SEPARATOR_L1, _owner, _spender, _amount, _deadline, _v, _r, _s);
    }

    /***************************************
                     HELPERS
    ****************************************/

    function _mintAppPoints(address _owner, uint256 _amount) internal {
        uint256 propsTreasuryAmount = _amount.mul(propsTreasuryMintPercentage).div(1e6);
        uint256 ownerAmount = _amount.sub(propsTreasuryAmount);

        _mint(propsTreasury, propsTreasuryAmount);
        _mint(_owner, ownerAmount);

        lastMint = block.timestamp;
    }
}
