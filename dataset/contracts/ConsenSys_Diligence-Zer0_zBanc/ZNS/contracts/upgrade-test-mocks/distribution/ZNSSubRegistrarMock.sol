// SPDX-License-Identifier: MIT
/* solhint-disable */
pragma solidity 0.8.18;

// solhint-disable
import { ZNSSubRegistrar } from "../../registrar/ZNSSubRegistrar.sol";
import { UpgradeMock } from "../UpgradeMock.sol";
import { IZNSPricer } from "../../types/IZNSPricer.sol";
import { IZNSRootRegistrar, CoreRegisterArgs } from "../../registrar/IZNSRootRegistrar.sol";
import { AAccessControlled } from "../../access/AAccessControlled.sol";
import { ARegistryWired } from "../../registry/ARegistryWired.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { StringUtils } from "../../utils/StringUtils.sol";
import { PaymentConfig } from "../../treasury/IZNSTreasury.sol";


enum AccessType {
    LOCKED,
    OPEN,
    MINTLIST
}

enum PaymentType {
    DIRECT,
    STAKE
}

struct DistributionConfig {
    IZNSPricer pricerContract;
    PaymentType paymentType;
    AccessType accessType;
    address newAddress;
    uint256 newUint;
}


contract ZNSSubRegistrarMainState {
    IZNSRootRegistrar public rootRegistrar;

    mapping(bytes32 domainHash => DistributionConfig config) public distrConfigs;

    mapping(bytes32 domainHash => mapping(address candidate => bool allowed)) public mintlist;
}


contract ZNSSubRegistrarUpgradeMock is
    AAccessControlled,
    ARegistryWired,
    UUPSUpgradeable,
    ZNSSubRegistrarMainState,
    UpgradeMock {

    using StringUtils for string;

    modifier onlyOwnerOperatorOrRegistrar(bytes32 domainHash) {
        require(
            registry.isOwnerOrOperator(domainHash, msg.sender)
            || accessController.isRegistrar(msg.sender),
            "ZNSSubRegistrar: Not authorized"
        );
        _;
    }

    function initialize(
        address _accessController,
        address _registry,
        address _rootRegistrar
    ) external initializer {
        _setAccessController(_accessController);
        setRegistry(_registry);
        setRootRegistrar(_rootRegistrar);
    }

    function registerSubdomain(
        bytes32 parentHash,
        string calldata label,
        address domainAddress,
        string memory tokenURI,
        DistributionConfig calldata distrConfig,
        PaymentConfig calldata paymentConfig
    ) external returns (bytes32) {
        label.validate();

        DistributionConfig memory parentConfig = distrConfigs[parentHash];

        bool isOwnerOrOperator = registry.isOwnerOrOperator(parentHash, msg.sender);
        require(
            parentConfig.accessType != AccessType.LOCKED || isOwnerOrOperator,
            "ZNSSubRegistrar: Parent domain's distribution is locked or parent does not exist"
        );

        if (parentConfig.accessType == AccessType.MINTLIST) {
            require(
                mintlist[parentHash][msg.sender],
                "ZNSSubRegistrar: Sender is not approved for purchase"
            );
        }

        CoreRegisterArgs memory coreRegisterArgs = CoreRegisterArgs({
            parentHash: parentHash,
            domainHash: hashWithParent(parentHash, label),
            label: label,
            registrant: msg.sender,
            price: 0,
            stakeFee: 0,
            domainAddress: domainAddress,
            tokenURI: tokenURI,
            isStakePayment: parentConfig.paymentType == PaymentType.STAKE,
            paymentConfig: paymentConfig
        });

        require(
            !registry.exists(coreRegisterArgs.domainHash),
            "ZNSSubRegistrar: Subdomain already exists"
        );

        if (!isOwnerOrOperator) {
            if (coreRegisterArgs.isStakePayment) {
                (coreRegisterArgs.price, coreRegisterArgs.stakeFee) = IZNSPricer(address(parentConfig.pricerContract))
                .getPriceAndFee(
                    parentHash,
                    label,
                    true
                );
            } else {
                coreRegisterArgs.price = IZNSPricer(address(parentConfig.pricerContract))
                    .getPrice(
                    parentHash,
                    label,
                    true
                );
            }
        }

        rootRegistrar.coreRegister(coreRegisterArgs);

        if (address(distrConfig.pricerContract) != address(0)) {
            setDistributionConfigForDomain(coreRegisterArgs.domainHash, distrConfig);
        }

        return coreRegisterArgs.domainHash;
    }

    function hashWithParent(
        bytes32 parentHash,
        string calldata label
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                parentHash,
                keccak256(bytes(label))
            )
        );
    }

    function setDistributionConfigForDomain(
        bytes32 domainHash,
        DistributionConfig calldata config
    ) public onlyOwnerOperatorOrRegistrar(domainHash) {
        require(
            address(config.pricerContract) != address(0),
            "ZNSSubRegistrar: pricerContract can not be 0x0 address"
        );

        distrConfigs[domainHash] = config;
    }

    function setPricerContractForDomain(
        bytes32 domainHash,
        IZNSPricer pricerContract
    ) public {
        require(
            registry.isOwnerOrOperator(domainHash, msg.sender),
            "ZNSSubRegistrar: Not authorized"
        );

        require(
            address(pricerContract) != address(0),
            "ZNSSubRegistrar: pricerContract can not be 0x0 address"
        );

        distrConfigs[domainHash].pricerContract = pricerContract;
    }

    function setPaymentTypeForDomain(
        bytes32 domainHash,
        PaymentType paymentType
    ) public {
        require(
            registry.isOwnerOrOperator(domainHash, msg.sender),
            "ZNSSubRegistrar: Not authorized"
        );

        distrConfigs[domainHash].paymentType = paymentType;
    }

    function _setAccessTypeForDomain(
        bytes32 domainHash,
        AccessType accessType
    ) internal {
        distrConfigs[domainHash].accessType = accessType;
    }

    function setAccessTypeForDomain(
        bytes32 domainHash,
        AccessType accessType
    ) external onlyOwnerOperatorOrRegistrar(domainHash) {
        _setAccessTypeForDomain(domainHash, accessType);
    }

    function updateMintlistForDomain(
        bytes32 domainHash,
        address[] calldata candidates,
        bool[] calldata allowed
    ) external {
        require(
            registry.isOwnerOrOperator(domainHash, msg.sender),
            "ZNSSubRegistrar: Not authorized"
        );

        for (uint256 i; i < candidates.length; i++) {
            mintlist[domainHash][candidates[i]] = allowed[i];
        }
    }

    function setRegistry(address registry_) public override onlyAdmin {
        _setRegistry(registry_);
    }

    function setRootRegistrar(address registrar_) public onlyAdmin {
        require(registrar_ != address(0), "ZNSSubRegistrar: _registrar can not be 0x0 address");
        rootRegistrar = IZNSRootRegistrar(registrar_);
    }

    /**
     * @notice To use UUPS proxy we override this function and revert if `msg.sender` isn't authorized
     * @param newImplementation The implementation contract to upgrade to
     */
    // solhint-disable-next-line
    function _authorizeUpgrade(address newImplementation) internal view override {
        accessController.checkGovernor(msg.sender);
    }
}
