// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "../PrivateOffer.sol";
import "./VestingCloneFactory.sol";

/**
 * @title PrivateOfferFactory
 * @author malteish, cjentzsch
 * @notice This contract deploys PrivateOffers using create2. It is used to deploy PrivateOffers with a deterministic address.
 * I also deploys the vesting contracts used for token lockup.
 * @dev One deployment of this contract can be used for deployment of any number of PrivateOffers using create2.
 */
contract PrivateOfferFactory {
    event Deploy(address indexed privateOffer);
    event NewPrivateOfferWithLockup(address privateOffer, address vesting);

    VestingCloneFactory public immutable vestingCloneFactory;

    constructor(VestingCloneFactory _vestingCloneFactory) {
        require(address(_vestingCloneFactory) != address(0), "VestingCloneFactory must not be 0");
        vestingCloneFactory = _vestingCloneFactory;
    }

    /**
     * @notice Deploys a contract using create2. During the deployment, `_currencyPayer` pays `_currencyReceiver` for the purchase of `_tokenAmount` tokens at `_tokenPrice` per token.
     *      The tokens are minted to `_tokenReceiver`. The token is deployed at `_token` and the currency is `_currency`.
     */
    function deployPrivateOffer(
        bytes32 _rawSalt,
        PrivateOfferArguments calldata _arguments
    ) external returns (address) {
        return _deployPrivateOffer(_rawSalt, _arguments);
    }

    /**
     * @notice Deploys a contract using create2. During the deployment, `_currencyPayer` pays `_currencyReceiver` for the purchase of `_tokenAmount` tokens at `_tokenPrice` per token.
     *      The tokens are minted to `_tokenReceiver`. The token is deployed at `_token` and the currency is `_currency`.
     * @param _rawSalt Value influencing the addresses of the deployed contract, but nothing else.
     * @param _arguments Arguments for the PrivateOffer contract.
     * @param _vestingStart The start of the vesting period.
     * @param _vestingCliff The cliff of the vesting period.
     * @param _vestingDuration The duration of the vesting period.
     * @param _vestingContractOwner The owner of the vesting contract.
     */
    function deployPrivateOfferWithTimeLock(
        bytes32 _rawSalt,
        PrivateOfferArguments calldata _arguments,
        uint64 _vestingStart,
        uint64 _vestingCliff,
        uint64 _vestingDuration,
        address _vestingContractOwner,
        address trustedForwarder
    ) external returns (address) {
        bytes32 salt = _getSalt(
            _rawSalt,
            _arguments,
            _vestingStart,
            _vestingCliff,
            _vestingDuration,
            _vestingContractOwner
        );

        // deploy the vesting contract
        Vesting vesting = Vesting(
            vestingCloneFactory.createVestingClone(salt, trustedForwarder, address(this), address(_arguments.token))
        );

        // create the vesting plan
        vesting.createVesting(
            _arguments.tokenAmount,
            _arguments.tokenReceiver,
            _vestingStart,
            _vestingCliff,
            _vestingDuration,
            false
        ); // this plan is not mintable

        vesting.removeManager(address(this));

        // transfer ownership of the vesting contract
        if (_vestingContractOwner == address(0)) {
            // if the owner is 0, the vesting contract will not have an owner. So no one can interfere with the vesting.
            vesting.renounceOwnership();
        } else {
            vesting.transferOwnership(_vestingContractOwner);
        }

        // deploy the private offer
        PrivateOfferArguments memory calldataArguments = _arguments;
        calldataArguments.tokenReceiver = address(vesting);
        // update currency receiver to be the vesting contract

        address privateOffer = _deployPrivateOffer(_rawSalt, calldataArguments);

        require(_arguments.token.balanceOf(address(vesting)) == _arguments.tokenAmount, "Execution failed");
        emit NewPrivateOfferWithLockup(address(privateOffer), address(vesting));
        return address(vesting);
    }

    /**
     * @notice Predicts the addresses of the PrivateOffer and Vesting contracts that would be deployed with the given parameters.
     * @param _rawSalt Value influencing the addresses of the deployed contracts, but nothing else.
     * @param _arguments Arguments for the PrivateOffer contract.
     * @param _vestingStart Begin of the vesting period.
     * @param _vestingCliff Cliff duration.
     * @param _vestingDuration Total vesting duration.
     * @param _vestingContractOwner Address that will own the vesting contract (note: this is not the token receiver or the beneficiary, but rather the company admin)
     * @param trustedForwarder ERC2771 trusted forwarder address
     * @return privateOfferAddress The address of the PrivateOffer contract that would be deployed.
     * @return vestingAddress The address of the Vesting contract that would be deployed.
     */
    function predictPrivateOfferAndTimeLockAddress(
        bytes32 _rawSalt,
        PrivateOfferArguments calldata _arguments,
        uint64 _vestingStart,
        uint64 _vestingCliff,
        uint64 _vestingDuration,
        address _vestingContractOwner,
        address trustedForwarder
    ) public view returns (address, address) {
        bytes32 salt = _getSalt(
            _rawSalt,
            _arguments,
            _vestingStart,
            _vestingCliff,
            _vestingDuration,
            _vestingContractOwner
        );
        address vestingAddress = vestingCloneFactory.predictCloneAddress(
            salt,
            trustedForwarder,
            address(this),
            address(_arguments.token)
        );

        // since the vesting contracts address will be used as the token receiver, we need to use it for the prediction
        PrivateOfferArguments memory arguments = _arguments;
        arguments.tokenReceiver = vestingAddress;
        address privateOfferAddress = predictPrivateOfferAddress(_rawSalt, arguments);

        return (privateOfferAddress, vestingAddress);
    }

    /**
     * @notice Predicts the address of the PrivateOffer contract that would be deployed with the given parameters.
     * @param _salt Value influencing the addresses of the deployed contract, but nothing else.
     * @param _arguments Parameters for the PrivateOffer contract (which also influence the address of the deployed contract)
     */
    function predictPrivateOfferAddress(
        bytes32 _salt,
        PrivateOfferArguments memory _arguments
    ) public view returns (address) {
        bytes memory bytecode = _getBytecode(_arguments);
        return Create2.computeAddress(_salt, keccak256(bytecode));
    }

    /**
     * Calculates a salt from all input parameters.
     * @param _rawSalt Value influencing the addresses of the deployed contract, but nothing else.
     * @param _arguments Arguments for the PrivateOffer contract.
     * @param _vestingStart Begin of the vesting period.
     * @param _vestingCliff Cliff duration.
     * @param _vestingDuration Total vesting duration.
     * @param _vestingContractOwner Address that will own the vesting contract (note: this is not the token receiver or the beneficiary, but rather the company admin)
     */
    function _getSalt(
        bytes32 _rawSalt,
        PrivateOfferArguments calldata _arguments,
        uint64 _vestingStart,
        uint64 _vestingCliff,
        uint64 _vestingDuration,
        address _vestingContractOwner
    ) private pure returns (bytes32) {
        return
            keccak256(
                abi.encode(_rawSalt, _arguments, _vestingStart, _vestingCliff, _vestingDuration, _vestingContractOwner)
            );
    }

    /**
     * @dev Generates the bytecode of the contract to be deployed, using the parameters.
     * @param _arguments Arguments for the PrivateOffer contract.
     * @return bytecode of the contract to be deployed.
     */
    function _getBytecode(PrivateOfferArguments memory _arguments) private pure returns (bytes memory) {
        return abi.encodePacked(type(PrivateOffer).creationCode, abi.encode(_arguments));
    }

    /**
     * Creates a PrivateOffer contract using create2.
     * @param _rawSalt Value influencing the addresses of the deployed contract, but nothing else.
     * @param _arguments Parameters for the PrivateOffer contract (which also influence the address of the deployed contract)
     */
    function _deployPrivateOffer(bytes32 _rawSalt, PrivateOfferArguments memory _arguments) private returns (address) {
        address privateOffer = Create2.deploy(0, _rawSalt, _getBytecode(_arguments));

        emit Deploy(privateOffer);
        return privateOffer;
    }
}
