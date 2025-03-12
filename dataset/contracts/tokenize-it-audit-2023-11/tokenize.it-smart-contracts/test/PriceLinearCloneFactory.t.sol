// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/factories/PriceLinearCloneFactory.sol";

contract PriceLinearCloneFactoryTest is Test {
    PriceLinearCloneFactory factory;
    PriceLinear oracle;

    address public constant companyAdmin = address(1);
    address public trustedForwarder = address(2);

    function setUp() public {
        // set up price oracle factory
        PriceLinear priceLinearLogicContract = new PriceLinear(trustedForwarder);
        factory = new PriceLinearCloneFactory(address(priceLinearLogicContract));
    }

    function testAddressPrediction(
        bytes32 _rawSalt,
        address _owner,
        uint64 _slopeEnumerator,
        uint64 _slopeDenominator,
        uint64 _startTimeOrBlockNumber,
        uint32 _stepDuration,
        bool _isBlockBased,
        bool _isRising
    ) public {
        vm.assume(_owner != address(0));
        vm.assume(_slopeEnumerator != 0);
        vm.assume(_slopeDenominator != 0);
        vm.assume(_stepDuration != 0);
        vm.assume(_startTimeOrBlockNumber > 100);

        bytes32 salt = keccak256(
            abi.encodePacked(
                _rawSalt,
                trustedForwarder,
                _owner,
                _slopeEnumerator,
                _slopeDenominator,
                _startTimeOrBlockNumber,
                _stepDuration,
                _isBlockBased,
                _isRising
            )
        );

        address expected1 = factory.predictCloneAddress(salt);
        address expected2 = factory.predictCloneAddress(
            _rawSalt,
            trustedForwarder,
            _owner,
            _slopeEnumerator,
            _slopeDenominator,
            _startTimeOrBlockNumber,
            _stepDuration,
            _isBlockBased,
            _isRising
        );
        assertEq(expected1, expected2, "address prediction with salt and params not equal");

        address actual = factory.createPriceLinearClone(
            _rawSalt,
            trustedForwarder,
            _owner,
            _slopeEnumerator,
            _slopeDenominator,
            _startTimeOrBlockNumber,
            _stepDuration,
            _isBlockBased,
            _isRising
        );
        assertEq(expected1, actual, "address prediction failed");
    }

    function testWrongForwarderFails(address _wrongTrustedForwarder) public {
        vm.assume(_wrongTrustedForwarder != trustedForwarder);
        vm.assume(_wrongTrustedForwarder != address(0));

        // using a different trustedForwarder should fail
        vm.expectRevert("PriceLinearCloneFactory: Unexpected trustedForwarder");
        factory.createPriceLinearClone(
            bytes32(uint256(0)),
            _wrongTrustedForwarder,
            companyAdmin,
            1,
            1,
            uint64(block.timestamp + 1),
            1,
            false,
            true
        );

        // using the correct trustedForwarder should succeed
        factory.createPriceLinearClone(
            bytes32(uint256(2)),
            trustedForwarder,
            companyAdmin,
            1,
            1,
            uint64(block.timestamp + 1),
            1,
            false,
            true
        );
    }
}
