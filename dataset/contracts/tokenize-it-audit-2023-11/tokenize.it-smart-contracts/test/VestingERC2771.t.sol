// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "@opengsn/contracts/src/forwarder/Forwarder.sol";
import "../contracts/factories/VestingCloneFactory.sol";
import "./resources/FakePaymentToken.sol";

contract VestingERC2771Test is Test {
    // init forwarder
    Forwarder forwarder = new Forwarder();
    bytes32 domainSeparator;
    bytes32 requestType;

    // init vesting contracts
    Vesting logic = new Vesting(address(forwarder));
    Vesting vesting;
    VestingCloneFactory factory;

    // init token
    FakePaymentToken token;

    // DO NOT USE THESE KEYS IN PRODUCTION! They were generated and stored very unsafely.
    uint256 public constant adminPrivateKey = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    address public adminAddress = vm.addr(adminPrivateKey); // = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    uint256 public constant managerPrivateKey = 0x3c69254ad72222e3ddf37667b8173dd773bdbdfd93d4af1d192815ff0662de5f;
    address public managerAddress = vm.addr(managerPrivateKey); // = 0x38d6703d37988C644D6d31551e9af6dcB762E618;

    uint256 public constant beneficiaryPrivateKey = 0x8da4ef21b864d2cc526dbdb2a120bd2874c36c9d0a1fb7f8c63d7f7a8b41de8f;
    address public beneficiaryAddress = vm.addr(beneficiaryPrivateKey); // = 0x63FaC9201494f0bd17B9892B9fae4d52fe3BD377;

    address public constant relayer = 0xDFcEB49eD21aE199b33A76B726E2bea7A72127B0;

    uint256 public constant allocation = 100e18;
    uint64 public constant start = 1e9; // round amount of seconds is easily debuggable, this is around 32 years
    uint64 public constant cliff = 1e6;
    uint64 public constant duration = 4e6;
    bool public constant isMintable = false; // the vesting plan we create holds the funds in the vesting contract itself

    function setUp() public {
        vm.warp(1e9 - 365 days);

        // set up token
        token = new FakePaymentToken(allocation, 18);

        // init vesting contracts
        factory = new VestingCloneFactory(address(logic));
        vesting = Vesting(factory.createVestingClone(0, address(forwarder), adminAddress, address(token)));

        // add manager
        vm.prank(adminAddress);
        vesting.addManager(managerAddress);

        // fund vesting contract
        token.transfer(address(vesting), allocation);

        // register domain separator with forwarder. Since the forwarder does not check the domain separator, we can use any string as domain name.
        vm.recordLogs();
        forwarder.registerDomainSeparator(string(abi.encodePacked(address(vesting))), "v1.0"); // simply uses address string as name
        Vm.Log[] memory logs = vm.getRecordedLogs();
        // the next line extracts the domain separator from the event emitted by the forwarder
        domainSeparator = logs[0].topics[1]; // internally, the forwarder calls this domainHash in registerDomainSeparator. But expects is as domainSeparator in execute().
        console.log("domainSeparator", vm.toString(domainSeparator));
        require(forwarder.domains(domainSeparator), "Registering failed");

        // register request type with forwarder. Since the forwarder does not check the request type, we can use any string as function name.
        vm.recordLogs();
        forwarder.registerRequestType("someFunctionName", "some function parameters");
        logs = vm.getRecordedLogs();
        // the next line extracts the request type from the event emitted by the forwarder
        requestType = logs[0].topics[1];
        console.log("requestType", vm.toString(requestType));
        require(forwarder.typeHashes(requestType), "Registering failed");
    }

    /**
     * @notice Create a new vest as ward using a meta tx that is sent by relayer
     */
    function testInitERC2771() public {
        // build request
        bytes memory payload = abi.encodeWithSelector(
            vesting.createVesting.selector,
            allocation,
            beneficiaryAddress,
            start,
            cliff,
            duration,
            isMintable
        );

        IForwarder.ForwardRequest memory request = IForwarder.ForwardRequest({
            from: adminAddress,
            to: address(vesting),
            value: 0,
            gas: 1000000,
            nonce: forwarder.getNonce(adminAddress),
            data: payload,
            validUntil: block.timestamp + 1 hours // like this, the signature will expire after 1 hour. So the platform hotwallet can take some time to execute the transaction.
        });

        bytes memory suffixData = "0";

        // pack and hash request
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(forwarder._getEncoded(request, requestType, suffixData))
            )
        );

        // sign request.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(adminPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v); // https://docs.openzeppelin.com/contracts/2.x/utilities

        require(address(this) != adminAddress, "sender is the admin");
        vm.prank(relayer);
        forwarder.execute(request, domainSeparator, requestType, suffixData, signature);

        //vm.prank(adminAddress);
        //vesting.createVesting(allocation, beneficiaryAddress, start, cliff, duration, true);

        console.log("signing address: ", request.from);

        uint64 id = 1;

        // confirm vesting plan was created with proper values
        assertEq(vesting.allocation(id), allocation, "total is wrong");
        assertEq(vesting.released(id), 0, "released is wrong");
        assertEq(vesting.beneficiary(id), beneficiaryAddress, "beneficiary is wrong");
        assertEq(vesting.start(id), start, "start is wrong");
        assertEq(vesting.cliff(id), cliff, "cliff is wrong");
        assertEq(vesting.duration(id), duration, "duration is wrong");
        assertEq(vesting.isMintable(id), isMintable, "mintable is wrong");
    }

    /**
     * @notice Trigger payout as user using a meta tx that is sent by relayer
     * @dev Many local variables had to be removed to avoid stack too deep error
     */
    function testVestERC2771() public {
        vm.prank(adminAddress);
        uint64 id = vesting.createVesting(allocation, beneficiaryAddress, start, cliff, duration, isMintable);

        vm.warp(start + duration);

        // prepare
        IForwarder.ForwardRequest memory request = IForwarder.ForwardRequest({
            from: beneficiaryAddress,
            to: address(vesting),
            value: 0,
            gas: 1000000,
            nonce: forwarder.getNonce(beneficiaryAddress),
            data: abi.encodeWithSelector(bytes4(keccak256(bytes("release(uint64)"))), id),
            validUntil: block.timestamp + 1 hours // like this, the signature will expire after 1 hour. So the platform hotwallet can take some time to execute the transaction.
        });

        // sign request.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            beneficiaryPrivateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    domainSeparator,
                    keccak256(forwarder._getEncoded(request, requestType, "0"))
                )
            )
        );

        assertEq(token.balanceOf(beneficiaryAddress), 0, "beneficiary balance is wrong before release");

        vm.prank(relayer);
        forwarder.execute(request, domainSeparator, requestType, "0", abi.encodePacked(r, s, v));

        // confirm vesting plan was created with proper values
        assertEq(vesting.allocation(id), allocation, "total is wrong");
        assertEq(vesting.released(id), allocation, "released is wrong");
        assertEq(vesting.beneficiary(id), beneficiaryAddress, "beneficiary is wrong");
        assertEq(vesting.start(id), start, "start is wrong");
        assertEq(vesting.cliff(id), cliff, "cliff is wrong");
        assertEq(vesting.duration(id), duration, "duration is wrong");
        assertEq(vesting.isMintable(id), isMintable, "mintable is wrong");

        assertEq(token.balanceOf(beneficiaryAddress), allocation, "beneficiary balance is wrong after release");
    }

    /**
     * @notice Yank a vesting contract as manager using a meta tx that is sent by relayer.
     */
    function testStopAfterReleaseERC2771() public {
        // Test case where yanked is called after a partial vest
        vm.prank(adminAddress);
        uint64 id = vesting.createVesting(allocation, beneficiaryAddress, start, cliff, duration, isMintable);
        vm.warp(start + duration / 2);
        assertEq(vesting.releasable(id), allocation / 2);

        // usr collects some of their value
        vm.prank(beneficiaryAddress);
        vesting.release(id); // collect some now
        assertEq(token.balanceOf(beneficiaryAddress), allocation / 2);

        uint64 stopTime = start + (duration * 3) / 4;

        // prepare meta-tx to yank as mgr
        bytes memory payload = abi.encodeWithSelector(vesting.stopVesting.selector, id, stopTime);

        IForwarder.ForwardRequest memory request = IForwarder.ForwardRequest({
            from: managerAddress,
            to: address(vesting),
            value: 0,
            gas: 1000000,
            nonce: forwarder.getNonce(managerAddress),
            data: payload,
            validUntil: block.timestamp + 1 hours // like this, the signature will expire after 1 hour. So the platform hotwallet can take some time to execute the transaction.
        });

        bytes memory suffixData = "0";

        // pack and hash request
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(forwarder._getEncoded(request, requestType, suffixData))
            )
        );

        // sign request.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(managerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v); // https://docs.openzeppelin.com/contracts/2.x/utilities

        vm.prank(relayer);
        forwarder.execute(request, domainSeparator, requestType, suffixData, signature);

        vm.warp(start + duration);

        // confirm vesting plan was created with proper values
        assertEq(vesting.allocation(id), (allocation * 3) / 4, "total is wrong");
        assertEq(vesting.released(id), allocation / 2, "released is wrong");
        assertEq(vesting.beneficiary(id), beneficiaryAddress, "beneficiary is wrong");
        assertEq(vesting.start(id), start, "start is wrong");
        assertEq(vesting.cliff(id), cliff, "cliff is wrong");
        assertEq(vesting.duration(id), (duration * 3) / 4, "duration is wrong");
        assertEq(vesting.isMintable(id), isMintable, "mintable is wrong");
        assertEq(vesting.releasable(id), allocation / 4, "releasable is wrong");
    }
}
