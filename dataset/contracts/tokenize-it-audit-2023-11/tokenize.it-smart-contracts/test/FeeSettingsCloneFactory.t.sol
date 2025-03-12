// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/FeeSettingsCloneFactory.sol";

contract tokenTest is Test {
    FeeSettingsCloneFactory factory;

    // address public constant admin = 0x0109709eCFa91a80626FF3989D68f67f5b1dD120;
    // address public constant requirer = 0x1109709ecFA91a80626ff3989D68f67F5B1Dd121;
    // address public constant transfererAdmin = 0x5109709EcFA91a80626ff3989d68f67F5B1dD125;
    // address public constant transferer = 0x6109709EcFA91A80626FF3989d68f67F5b1dd126;
    // address public constant pauser = 0x7109709eCfa91A80626Ff3989D68f67f5b1dD127;

    bytes32 exampleRawSalt = "salt";
    address public constant exampleToken = 0x8109709ecfa91a80626fF3989d68f67F5B1dD128;
    address public constant exampleTrustedForwarder = 0x9109709EcFA91A80626FF3989D68f67F5B1dD129;
    address public constant exampleOwner = 0x2109709EcFa91a80626Ff3989d68F67F5B1Dd122;
    address public constant exampleTokenFeeCollector = 0x3109709ECfA91A80626fF3989D68f67F5B1Dd123;
    address public constant exampleCrowdinvestingFeeCollector = 0x4109709eCFa91A80626ff3989d68F67f5b1DD124;
    address public constant examplePrivateOfferFeeCollector = 0x4109709eCFa91A80626ff3989d68F67f5b1DD124;
    Fees exampleFees1 = Fees(1, 30, 2, 40, 3, 90, 0);
    Fees exampleFees2 = Fees(0, 3, 1, 50, 2, 80, 0);

    function setUp() public {
        factory = new FeeSettingsCloneFactory(address(new FeeSettings(exampleTrustedForwarder)));
    }

    function testAddressPrediction(
        bytes32 _rawSalt,
        address _owner,
        address _tokenFeeCollector,
        address _crowdinvestingFeeCollector,
        address _privateOfferFeeCollector
    ) public {
        vm.assume(_owner != address(0));
        vm.assume(_tokenFeeCollector != address(0));
        vm.assume(_crowdinvestingFeeCollector != address(0));
        vm.assume(_privateOfferFeeCollector != address(0));

        bytes32 salt = keccak256(
            abi.encode(
                _rawSalt,
                exampleTrustedForwarder,
                _owner,
                exampleFees1,
                _tokenFeeCollector,
                _crowdinvestingFeeCollector,
                _privateOfferFeeCollector
            )
        );

        address expected1 = factory.predictCloneAddress(salt);
        address expected2 = factory.predictCloneAddress(
            _rawSalt,
            exampleTrustedForwarder,
            _owner,
            exampleFees1,
            _tokenFeeCollector,
            _crowdinvestingFeeCollector,
            _privateOfferFeeCollector
        );

        address actual = factory.createFeeSettingsClone(
            _rawSalt,
            exampleTrustedForwarder,
            _owner,
            exampleFees1,
            _tokenFeeCollector,
            _crowdinvestingFeeCollector,
            _privateOfferFeeCollector
        );

        assertEq(expected1, expected2, "address prediction with salt and params not equal");
        assertEq(expected1, actual, "address prediction failed");
    }

    function testChangingParametersChangesAddress() public {
        address someAddress = address(42);

        address base = factory.predictCloneAddress(
            exampleRawSalt,
            exampleTrustedForwarder,
            exampleOwner,
            exampleFees1,
            exampleTokenFeeCollector,
            exampleCrowdinvestingFeeCollector,
            examplePrivateOfferFeeCollector
        );

        address changed = factory.predictCloneAddress(
            "0",
            exampleTrustedForwarder,
            exampleOwner,
            exampleFees2,
            exampleTokenFeeCollector,
            exampleCrowdinvestingFeeCollector,
            examplePrivateOfferFeeCollector
        );
        assertTrue(base != changed, "addresses equal with raw salt changed");

        changed = factory.predictCloneAddress(
            exampleRawSalt,
            exampleTrustedForwarder,
            exampleOwner,
            exampleFees2,
            exampleTokenFeeCollector,
            exampleCrowdinvestingFeeCollector,
            examplePrivateOfferFeeCollector
        );
        assertTrue(base != changed, "addresses equal with fees changed");

        changed = factory.predictCloneAddress(
            exampleRawSalt,
            someAddress,
            exampleOwner,
            exampleFees1,
            exampleTokenFeeCollector,
            exampleCrowdinvestingFeeCollector,
            examplePrivateOfferFeeCollector
        );
        assertTrue(base != changed, "addresses equal with trustedForwarder changed");

        changed = factory.predictCloneAddress(
            exampleRawSalt,
            exampleTrustedForwarder,
            someAddress,
            exampleFees1,
            exampleTokenFeeCollector,
            exampleCrowdinvestingFeeCollector,
            examplePrivateOfferFeeCollector
        );
        assertTrue(base != changed, "addresses equal with owner changed");

        changed = factory.predictCloneAddress(
            exampleRawSalt,
            exampleTrustedForwarder,
            exampleOwner,
            exampleFees1,
            someAddress,
            exampleCrowdinvestingFeeCollector,
            examplePrivateOfferFeeCollector
        );
        assertTrue(base != changed, "addresses equal with tokenFeeCollector changed");

        changed = factory.predictCloneAddress(
            exampleRawSalt,
            exampleTrustedForwarder,
            exampleOwner,
            exampleFees1,
            exampleTokenFeeCollector,
            someAddress,
            examplePrivateOfferFeeCollector
        );
        assertTrue(base != changed, "addresses equal with crowdinvestingFeeCollector changed");

        changed = factory.predictCloneAddress(
            exampleRawSalt,
            exampleTrustedForwarder,
            exampleOwner,
            exampleFees1,
            exampleTokenFeeCollector,
            exampleCrowdinvestingFeeCollector,
            someAddress
        );
        assertTrue(base != changed, "addresses equal with privateOfferFeeCollector changed");
    }

    function testSecondDeploymentFails() public {
        factory.createFeeSettingsClone(
            exampleRawSalt,
            exampleTrustedForwarder,
            exampleOwner,
            exampleFees1,
            exampleTokenFeeCollector,
            exampleCrowdinvestingFeeCollector,
            examplePrivateOfferFeeCollector
        );

        vm.expectRevert("ERC1167: create2 failed");
        factory.createFeeSettingsClone(
            exampleRawSalt,
            exampleTrustedForwarder,
            exampleOwner,
            exampleFees1,
            exampleTokenFeeCollector,
            exampleCrowdinvestingFeeCollector,
            examplePrivateOfferFeeCollector
        );
    }

    function testInitialization(
        address _owner,
        address _tokenFeeCollector,
        address _crowdinvestingFeeCollector,
        address _privateOfferFeeCollector
    ) public {
        vm.assume(_owner != address(0));
        vm.assume(_tokenFeeCollector != address(0));
        vm.assume(_crowdinvestingFeeCollector != address(0));
        vm.assume(_privateOfferFeeCollector != address(0));

        FeeSettings feeSettings = FeeSettings(
            factory.createFeeSettingsClone(
                exampleRawSalt,
                exampleTrustedForwarder,
                _owner,
                exampleFees1,
                _tokenFeeCollector,
                _crowdinvestingFeeCollector,
                _privateOfferFeeCollector
            )
        );

        assertEq(feeSettings.owner(), _owner, "owner not set");
        assertEq(feeSettings.tokenFeeCollector(exampleToken), _tokenFeeCollector, "tokenFeeCollector not set");
        assertEq(
            feeSettings.crowdinvestingFeeCollector(exampleToken),
            _crowdinvestingFeeCollector,
            "crowdinvestingFeeCollector not set"
        );
        assertEq(
            feeSettings.privateOfferFeeCollector(exampleToken),
            _privateOfferFeeCollector,
            "privateOfferFeeCollector not set"
        );
        assertEq(
            feeSettings.defaultTokenFeeNumerator(),
            exampleFees1.tokenFeeNumerator,
            "defaultTokenFeeNumerator not set"
        );
        assertEq(
            feeSettings.defaultTokenFeeDenominator(),
            exampleFees1.tokenFeeDenominator,
            "defaultTokenFeeDenominator not set"
        );
        assertEq(
            feeSettings.defaultCrowdinvestingFeeNumerator(),
            exampleFees1.crowdinvestingFeeNumerator,
            "defaultCrowdinvestingFeeNumerator not set"
        );
        assertEq(
            feeSettings.defaultCrowdinvestingFeeDenominator(),
            exampleFees1.crowdinvestingFeeDenominator,
            "defaultCrowdinvestingFeeDenominator not set"
        );
        assertEq(
            feeSettings.defaultPrivateOfferFeeNumerator(),
            exampleFees1.privateOfferFeeNumerator,
            "defaultPrivateOfferFeeNumerator not set"
        );
        assertEq(
            feeSettings.defaultPrivateOfferFeeDenominator(),
            exampleFees1.privateOfferFeeDenominator,
            "defaultPrivateOfferFeeDenominator not set"
        );
    }
}
