// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;
pragma experimental ABIEncoderV2;

import {IERC20} from "./Dependencies/IERC20.sol";
import {IOracle} from "./Interfaces/IOracle.sol";
import {SafeMath} from "./Dependencies/SafeMath.sol";
import {AccessControl} from "./Dependencies/AccessControl.sol";
import {IARTHController} from "./Dependencies/IARTHController.sol";
import {IUniswapPairOracle} from "./Dependencies/IUniswapPairOracle.sol";

contract ARTHController is AccessControl, IARTHController {
    using SafeMath for uint256;

    IERC20 public ARTH;
    IERC20 public MAHA;

    IUniswapPairOracle public MAHAGMUOracle;

    address public ownerAddress;
    address public timelockAddress;
    address public DEFAULT_ADMIN_ADDRESS;

    address[] public arthPoolsArray; // These contracts are able to mint ARTH.
    mapping(address => bool) public arthPools;

    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            'ARTHController: FORBIDDEN'
        );
        _;
    }

    modifier onlyByOwnerOrGovernance() {
        require(
            msg.sender == ownerAddress || msg.sender == timelockAddress,
            'ARTHController: FORBIDDEN'
        );
        _;
    }

    modifier onlyByOwnerGovernanceOrPool() {
        require(
            msg.sender == ownerAddress ||
                msg.sender == timelockAddress ||
                arthPools[msg.sender],
            "ARTHController: FORBIDDEN"
        );
        _;
    }

    constructor(
        IERC20 _arth,
        IERC20 _maha,
        address _owner,
        address _timelockAddress
    ) public {
        ARTH = _arth;
        MAHA = _maha;

        timelockAddress = _timelockAddress;

        DEFAULT_ADMIN_ADDRESS = _msgSender();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        ownerAddress = _owner;
    }

    /// @notice Adds collateral addresses supported.
    /// @dev    Collateral must be an ERC20.
    function addPool(address poolAddress)
        external
        override
        onlyByOwnerOrGovernance
    {
        require(!arthPools[poolAddress], 'ARTHController: address present');

        arthPools[poolAddress] = true;
        arthPoolsArray.push(poolAddress);
    }

    function addPools(address[] memory poolAddress)
        external
        override
        onlyByOwnerOrGovernance
    {
        for (uint256 index = 0; index < poolAddress.length; index++) {
            arthPools[poolAddress[index]] = true;
            arthPoolsArray.push(poolAddress[index]);
        }
    }

    function removePool(address poolAddress)
        external
        override
        onlyByOwnerOrGovernance
    {
        require(arthPools[poolAddress], 'ARTHController: address absent');

        // Delete from the mapping.
        delete arthPools[poolAddress];

        uint256 noOfPools = arthPoolsArray.length;
        // 'Delete' from the array by setting the address to 0x0
        for (uint256 i = 0; i < noOfPools; i++) {
            if (arthPoolsArray[i] == poolAddress) {
                arthPoolsArray[i] = address(0); // This will leave a null in the array and keep the indices the same.
                break;
            }
        }
    }

    function setMAHAGMUOracle(address oracle)
        external
        override
        onlyByOwnerOrGovernance
    {
        MAHAGMUOracle = IUniswapPairOracle(oracle);
    }

    function setOwner(address _ownerAddress)
        external
        override
        onlyByOwnerOrGovernance
    {
        ownerAddress = _ownerAddress;
    }

    function setTimelock(address newTimelock)
        external
        override
        onlyByOwnerOrGovernance
    {
        timelockAddress = newTimelock;
    }

    function getMAHAPrice() public view override returns (uint256) {
        return MAHAGMUOracle.consult(address(MAHA), 1e18);
    }

    function isPool(address pool) external view override returns (bool) {
        return arthPools[pool];
    }

    // function getGlobalCollateralValue() public view override returns (uint256) {
    //     uint256 totalCollateralValueD18 = 0;

    //     uint256 noOfPools = arthPoolsArray.length;
    //     for (uint256 i = 0; i < noOfPools; i++) {
    //         // Exclude null addresses.
    //         if (arthPoolsArray[i] != address(0)) {
    //             totalCollateralValueD18 = totalCollateralValueD18.add(
    //                 IARTHPool(arthPoolsArray[i]).getCollateralGMUBalance()
    //             );
    //         }
    //     }

    //     return totalCollateralValueD18.add(collateralRaisedOnOtherChain);
    // }

    function getARTHSupply() public view override returns (uint256) {
        return ARTH.totalSupply();
    }

    // function getTargetCollateralValue() public view override returns (uint256) {
    //     return getARTHSupply().mul(getGlobalCollateralRatio()).div(1e6);
    // }

    // function getPercentCollateralized() public view override returns (uint256) {
    //     uint256 targetCollatValue = getTargetCollateralValue();
    //     uint256 currentCollatValue = getGlobalCollateralValue();

    //     return currentCollatValue.mul(1e18).div(targetCollatValue);
    // }
} 