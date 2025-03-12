pragma solidity >=0.5.12;

import { DssDeployTestBase } from "dss-deploy/DssDeploy.t.base.sol";
import "./Math.sol";

contract MathTest is DssDeployTestBase, Math {
    function setUp() public {
        super.setUp();
        deploy();
    }

    function testAddUintInt() public {
        assertEq(add(uint(123),int(3)), 123 + 3);
    }

    function testFailedAddUintInt() public {
        add(uint(-1),int(1));
    }

    function testAddUintUint() public {
        assertEq(add(uint(123),uint(234)), 123 + 234);
    }

    function testFailedAddUintUint() public {
        add(uint(-1) - 9,uint(11));
    }

    function testSubUintInt() public {
        assertEq(sub(uint(2343),int(23)), 2343 - 23);
    }

    function testFailedSubUintInt() public {
        sub(uint(3),int(23));
    }

    function testSubUintUint() public {
        assertEq(sub(uint(2346),int(26)), 2346 - 26);
    }

    function testFailedSubUintUint() public {
        sub(uint(3),uint(23));
    }

    function testMulUintInt() public {
        assertEq(mul(uint(2346),int(26)), 2346 * 26);
    }

    function testFailedMulUintInt() public {
        mul(uint(2**200),int(2**100));
    }

    function testMulUintUint() public {
        assertEq(mul(uint(2346),uint(26)), 2346 * 26);
    }

    function testFailedMulUintUint() public {
        mul(uint(2**200),uint(2**100));
    }

    function testRdiv() public {
        assertEq(rdiv(uint(2346),uint(26)), 2346 * uint(1e27) / 26);
    }

    function testFailedRdiv() public {
        rdiv(uint(2**250),uint(2));
    }

    function testRmul() public {
        assertEq(rmul(uint(2346),uint(26)), 2346 * 26 / uint(1e27));
    }

    function testFailedRmul() public {
        rmul(uint(2**200),uint(2**100));
    }

    function testRpow() public {
        uint result = rpow(1000234891009084238901289093,uint(3724),uint(1e27));
        // python calc = 2.397991232255757e27 = 2397991232255757e12

        // expect 10 decimal precision
        assertEq(result / uint(1e17), uint(2397991232255757e12) / 1e17);
    }
}
