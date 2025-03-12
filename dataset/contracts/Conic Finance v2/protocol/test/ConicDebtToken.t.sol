// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./ConicTest.sol";
import "../interfaces/IConicDebtToken.sol";
import "../contracts/ConicDebtToken.sol";

contract ConicDebtTokenTest is ConicTest {
    bytes32 constant MERKLE_ROOT_DEBT_TOKEN =
        0x5b09a6971fd93f3daecfe326ce01299059ec999160f4e731d964129accadbe9c;

    bytes32 constant MERKLE_ROOT_REFUND =
        0x332bbf7febd73292fc00b2a4beb458bde392a68bc8f7afa6fa5ad8c77bff8079;

    IConicDebtToken internal conicDebtToken;

    uint256 public decimals;

    function setUp() public override {
        super.setUp();
        _setFork(mainnetFork);
        vm.prank(bb8);
        conicDebtToken = new ConicDebtToken(MERKLE_ROOT_DEBT_TOKEN, MERKLE_ROOT_REFUND);
        decimals = IERC20Metadata(Tokens.CRVUSD).decimals();
        setTokenBalance(bb8, Tokens.CRVUSD, 500_000 * 10 ** decimals);
    }

    function testDepositRefund() public {
        assertEq(IERC20(Tokens.CRVUSD).balanceOf(bb8), 500_000 * 10 ** decimals);
        vm.startPrank(bb8);
        IERC20(Tokens.CRVUSD).approve(address(conicDebtToken), 500_000 * 10 ** decimals);
        conicDebtToken.depositRefund(500_000 * 10 ** decimals);
        assertEq(
            IERC20(Tokens.CRVUSD).balanceOf(address(conicDebtToken)),
            500_000 * 10 ** decimals
        );
        assertEq(IERC20(Tokens.CRVUSD).balanceOf(bb8), 0);
        emit log_address(bb8); // 0xE2Fca394F3a28F1717EFAB57339540306F303f6f
        emit log_address(c3po); // 0x6763367385beC272a5BA2C1Fb3e7FCd36485e4FD
        emit log_address(r2); // 0x2A71967CF1d84B413bb804418b54407822914D80
    }

    function testClaimRefund() public {
        vm.startPrank(bb8);
        IERC20(Tokens.CRVUSD).approve(address(conicDebtToken), 500_000 * 10 ** decimals);
        conicDebtToken.depositRefund(500_000 * 10 ** decimals);
        assertEq(
            IERC20(Tokens.CRVUSD).balanceOf(address(conicDebtToken)),
            500_000 * 10 ** decimals
        );
        assertEq(IERC20(Tokens.CRVUSD).balanceOf(bb8), 0);
        conicDebtToken.start();

        bytes32[] memory hashes = new bytes32[](2);
        hashes[0] = 0x69a7cea870a6863fa8c508b8da3b58f72cba93545e232bfbe242eae1fa876da5;
        hashes[1] = 0x493cc2e14f5b6b8cca8206817a5687a778a2cd3b7aa92fe1c9a6aced01bdfbf9;
        MerkleProof.Proof memory proof = MerkleProof.Proof({nodeIndex: 0, hashes: hashes});

        conicDebtToken.claimRefund(100000000000000000000000, proof);
        assertEq(IERC20(address(conicDebtToken)).balanceOf(bb8), 0);
        assertEq(IERC20(Tokens.CRVUSD).balanceOf(bb8), 100000000000000000000000);

        hashes[0] = 0x067372aeeab58eae6f6137b77649ec628cd48812dfdf5ca089b1ba81a697d2f0;
        hashes[1] = 0x493cc2e14f5b6b8cca8206817a5687a778a2cd3b7aa92fe1c9a6aced01bdfbf9;
        proof = MerkleProof.Proof({nodeIndex: 1, hashes: hashes});

        vm.stopPrank();
        vm.prank(c3po);
        conicDebtToken.claimRefund(80000000000000000000, proof);
        assertEq(IERC20(address(conicDebtToken)).balanceOf(c3po), 0);
        assertEq(IERC20(Tokens.CRVUSD).balanceOf(c3po), 80000000000000000000);
    }

    function testClaimRefundOnlyOnce() public {
        vm.startPrank(bb8);
        IERC20(Tokens.CRVUSD).approve(address(conicDebtToken), 500_000 * 10 ** decimals);
        conicDebtToken.depositRefund(500_000 * 10 ** decimals);
        assertEq(
            IERC20(Tokens.CRVUSD).balanceOf(address(conicDebtToken)),
            500_000 * 10 ** decimals
        );
        assertEq(IERC20(Tokens.CRVUSD).balanceOf(bb8), 0);
        conicDebtToken.start();

        bytes32[] memory hashes = new bytes32[](2);
        hashes[0] = 0x69a7cea870a6863fa8c508b8da3b58f72cba93545e232bfbe242eae1fa876da5;
        hashes[1] = 0x493cc2e14f5b6b8cca8206817a5687a778a2cd3b7aa92fe1c9a6aced01bdfbf9;
        MerkleProof.Proof memory proof = MerkleProof.Proof({nodeIndex: 0, hashes: hashes});

        conicDebtToken.claimRefund(100000000000000000000000, proof);
        assertEq(IERC20(address(conicDebtToken)).balanceOf(bb8), 0);
        assertEq(IERC20(Tokens.CRVUSD).balanceOf(bb8), 100000000000000000000000);

        vm.expectRevert();
        conicDebtToken.claimRefund(100000000000000000000000, proof);
    }

    function testClaimDebtToken() public {
        vm.startPrank(bb8);
        conicDebtToken.start();

        bytes32[] memory hashes = new bytes32[](2);
        hashes[0] = 0xcb4bae3216daa2eb5a11abce9cba1351e7e04b55d147f2c096cfd984c18cc5e3;
        hashes[1] = 0xbfce32bc65cab42c68e0d96d7217c6ca2102761ba3b5f2928e0cb76be7a26bd8;
        MerkleProof.Proof memory proof = MerkleProof.Proof({nodeIndex: 0, hashes: hashes});

        conicDebtToken.claimDebtToken(400000000000000000000000, proof);
        assertEq(IERC20(address(conicDebtToken)).balanceOf(bb8), 400000000000000000000000);
    }

    function testClaimDebtTokenOnlyOnce() public {
        vm.startPrank(bb8);
        conicDebtToken.start();

        bytes32[] memory hashes = new bytes32[](2);
        hashes[0] = 0xcb4bae3216daa2eb5a11abce9cba1351e7e04b55d147f2c096cfd984c18cc5e3;
        hashes[1] = 0xbfce32bc65cab42c68e0d96d7217c6ca2102761ba3b5f2928e0cb76be7a26bd8;
        MerkleProof.Proof memory proof = MerkleProof.Proof({nodeIndex: 0, hashes: hashes});

        conicDebtToken.claimDebtToken(400000000000000000000000, proof);
        assertEq(IERC20(address(conicDebtToken)).balanceOf(bb8), 400000000000000000000000);

        vm.expectRevert();
        conicDebtToken.claimDebtToken(1, proof);
    }

    function testClaimAll() public {
        vm.startPrank(bb8);
        IERC20(Tokens.CRVUSD).approve(address(conicDebtToken), 500_000 * 10 ** decimals);
        conicDebtToken.depositRefund(500_000 * 10 ** decimals);
        assertEq(
            IERC20(Tokens.CRVUSD).balanceOf(address(conicDebtToken)),
            500_000 * 10 ** decimals
        );
        assertEq(IERC20(Tokens.CRVUSD).balanceOf(bb8), 0);

        conicDebtToken.start();

        bytes32[] memory hashes1 = new bytes32[](2);
        hashes1[0] = 0xcb4bae3216daa2eb5a11abce9cba1351e7e04b55d147f2c096cfd984c18cc5e3;
        hashes1[1] = 0xbfce32bc65cab42c68e0d96d7217c6ca2102761ba3b5f2928e0cb76be7a26bd8;
        MerkleProof.Proof memory proof1 = MerkleProof.Proof({nodeIndex: 0, hashes: hashes1});

        bytes32[] memory hashes2 = new bytes32[](2);
        hashes2[0] = 0x69a7cea870a6863fa8c508b8da3b58f72cba93545e232bfbe242eae1fa876da5;
        hashes2[1] = 0x493cc2e14f5b6b8cca8206817a5687a778a2cd3b7aa92fe1c9a6aced01bdfbf9;
        MerkleProof.Proof memory proof2 = MerkleProof.Proof({nodeIndex: 0, hashes: hashes2});

        conicDebtToken.claimAll(400000000000000000000000, proof1, 100000000000000000000000, proof2);
        assertEq(IERC20(address(conicDebtToken)).balanceOf(bb8), 400000000000000000000000);
        assertEq(IERC20(Tokens.CRVUSD).balanceOf(bb8), 100000000000000000000000);
    }

    function testBurnOnlyClaimPool() public {
        vm.startPrank(bb8);

        conicDebtToken.start();

        bytes32[] memory hashes = new bytes32[](2);
        hashes[0] = 0xcb4bae3216daa2eb5a11abce9cba1351e7e04b55d147f2c096cfd984c18cc5e3;
        hashes[1] = 0xbfce32bc65cab42c68e0d96d7217c6ca2102761ba3b5f2928e0cb76be7a26bd8;
        MerkleProof.Proof memory proof = MerkleProof.Proof({nodeIndex: 0, hashes: hashes});

        conicDebtToken.claimDebtToken(400000000000000000000000, proof);

        vm.expectRevert();
        conicDebtToken.burn(400000000000000000000000);

        conicDebtToken.setClaimPool(bb8);
        conicDebtToken.burn(400000000000000000000000);
    }
}
