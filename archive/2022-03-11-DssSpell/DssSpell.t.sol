// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.6.12;

import "./DssSpell.t.base.sol";
import "dss-interfaces/Interfaces.sol";

contract DssSpellTest is DssSpellTestBase {

    function testSpellIsCast_GENERAL() public {
        string memory description = new DssSpell().description();
        assertTrue(bytes(description).length > 0, "TestError/spell-description-length");
        // DS-Test can't handle strings directly, so cast to a bytes32.
        assertEq(stringToBytes32(spell.description()),
                stringToBytes32(description), "TestError/spell-description");

        if(address(spell) != address(spellValues.deployed_spell)) {
            assertEq(spell.expiration(), block.timestamp + spellValues.expiration_threshold, "TestError/spell-expiration");
        } else {
            assertEq(spell.expiration(), spellValues.deployed_spell_created + spellValues.expiration_threshold, "TestError/spell-expiration");

            // If the spell is deployed compare the on-chain bytecode size with the generated bytecode size.
            // extcodehash doesn't match, potentially because it's address-specific, avenue for further research.
            address depl_spell = spellValues.deployed_spell;
            address code_spell = address(new DssSpell());
            assertEq(getExtcodesize(depl_spell), getExtcodesize(code_spell), "TestError/spell-codesize");
        }

        assertTrue(spell.officeHours() == spellValues.office_hours_enabled, "TestError/spell-office-hours");

        vote(address(spell));
        scheduleWaitAndCast(address(spell));
        assertTrue(spell.done(), "TestError/spell-not-done");

        checkSystemValues(afterSpell);

        checkCollateralValues(afterSpell);
    }

    address constant WALLET1 = 0x3C32F2ca11D92a7093d1F237161C1fB692F6a8eA;
    address constant WALLET2 = 0x2BC5fFc5De1a83a9e4cDDfA138bAEd516D70414b;
    function testPayments() public {
        uint256 prevSin = vat.sin(address(vow));

        uint256 amt1 = 2_500 * WAD;
        uint256 amt2 = 250 * WAD;

        uint256 prev1 = dai.balanceOf(WALLET1);
        uint256 prev2 = dai.balanceOf(WALLET2);

        vote(address(spell));
        scheduleWaitAndCast(address(spell));
        assertTrue(spell.done());

        assertEq(vat.sin(address(vow)) - prevSin, (amt1 + amt2) * RAY);

        assertEq(dai.balanceOf(WALLET1) - prev1, amt1);
        assertEq(dai.balanceOf(WALLET2) - prev2, amt2);
    }

    function testCollateralIntegrations() public { // make public to use
        vote(address(spell));
        scheduleWaitAndCast(address(spell));
        assertTrue(spell.done());

        // Insert new collateral tests here
        checkCropCRVLPIntegration(
            "CRVV1ETHSTETH-A",
            CropJoinLike(addr.addr("MCD_JOIN_CRVV1ETHSTETH_A")),
            ClipAbstract(addr.addr("MCD_CLIP_CRVV1ETHSTETH_A")),
            CurveLPOsmLike(addr.addr("PIP_CRVV1ETHSTETH")),
            0x64DE91F5A373Cd4c28de3600cB34C7C6cE410C85,     // ETH Medianizer
            0x911D7A8F87282C4111f621e2D100Aa751Bab1260,     // stETH Medianizer (proxy to wstETH medianizer)
            true,
            true,
            true
        );
    }

    function testNewChainlogValues() public { // make public to use
        vote(address(spell));
        scheduleWaitAndCast(address(spell));
        assertTrue(spell.done());

        // Insert new chainlog values tests here
        assertEq(chainLog.getAddress("MCD_FLAP"), addr.addr("MCD_FLAP"));

        assertEq(chainLog.getAddress("CDP_REGISTRY"), addr.addr("CDP_REGISTRY"));
        assertEq(chainLog.getAddress("MCD_CROPPER"), addr.addr("MCD_CROPPER"));
        assertEq(chainLog.getAddress("MCD_CROPPER_IMP"), addr.addr("MCD_CROPPER_IMP"));
        assertEq(chainLog.getAddress("PROXY_ACTIONS_CROPPER"), addr.addr("PROXY_ACTIONS_CROPPER"));
        assertEq(chainLog.getAddress("PROXY_ACTIONS_END_CROPPER"), addr.addr("PROXY_ACTIONS_END_CROPPER"));

        assertEq(chainLog.getAddress("CRVV1ETHSTETH"), addr.addr("CRVV1ETHSTETH"));
        assertEq(chainLog.getAddress("PIP_CRVV1ETHSTETH"), addr.addr("PIP_CRVV1ETHSTETH"));
        assertEq(chainLog.getAddress("MCD_JOIN_CRVV1ETHSTETH_A"), addr.addr("MCD_JOIN_CRVV1ETHSTETH_A"));
        assertEq(chainLog.getAddress("MCD_CLIP_CRVV1ETHSTETH_A"), addr.addr("MCD_CLIP_CRVV1ETHSTETH_A"));
        assertEq(chainLog.getAddress("MCD_CLIP_CALC_CRVV1ETHSTETH_A"), addr.addr("MCD_CLIP_CALC_CRVV1ETHSTETH_A"));

        assertEq(chainLog.version(), "1.11.0");
    }

    function testNewIlkRegistryValues() public { // make public to use
        vote(address(spell));
        scheduleWaitAndCast(address(spell));
        assertTrue(spell.done());

        // Insert new ilk registry values tests here
        assertEq(reg.pos("CRVV1ETHSTETH-A"), 48);
        assertEq(reg.join("CRVV1ETHSTETH-A"), addr.addr("MCD_JOIN_CRVV1ETHSTETH_A"));
        assertEq(reg.gem("CRVV1ETHSTETH-A"), addr.addr("CRVV1ETHSTETH"));
        assertEq(reg.dec("CRVV1ETHSTETH-A"), DSTokenAbstract(addr.addr("CRVV1ETHSTETH")).decimals());
        assertEq(reg.class("CRVV1ETHSTETH-A"), 1);
        assertEq(reg.pip("CRVV1ETHSTETH-A"), addr.addr("PIP_CRVV1ETHSTETH"));
        assertEq(reg.xlip("CRVV1ETHSTETH-A"), addr.addr("MCD_CLIP_CRVV1ETHSTETH_A"));
        assertEq(reg.name("CRVV1ETHSTETH-A"), "Curve.fi ETH/stETH");
        assertEq(reg.symbol("CRVV1ETHSTETH-A"), "steCRV");
    }

    function testFailWrongDay() public {
        require(spell.officeHours() == spellValues.office_hours_enabled);
        if (spell.officeHours()) {
            vote(address(spell));
            scheduleWaitAndCastFailDay();
        } else {
            revert("Office Hours Disabled");
        }
    }

    function testFailTooEarly() public {
        require(spell.officeHours() == spellValues.office_hours_enabled);
        if (spell.officeHours()) {
            vote(address(spell));
            scheduleWaitAndCastFailEarly();
        } else {
            revert("Office Hours Disabled");
        }
    }

    function testFailTooLate() public {
        require(spell.officeHours() == spellValues.office_hours_enabled);
        if (spell.officeHours()) {
            vote(address(spell));
            scheduleWaitAndCastFailLate();
        } else {
            revert("Office Hours Disabled");
        }
    }

    function testOnTime() public {
        vote(address(spell));
        scheduleWaitAndCast(address(spell));
    }

    function testCastCost() public {
        vote(address(spell));
        spell.schedule();

        castPreviousSpell();
        hevm.warp(spell.nextCastTime());
        uint256 startGas = gasleft();
        spell.cast();
        uint256 endGas = gasleft();
        uint256 totalGas = startGas - endGas;

        assertTrue(spell.done());
        // Fail if cast is too expensive
        assertTrue(totalGas <= 10 * MILLION);
    }

    // The specific date doesn't matter that much since function is checking for difference between warps
    function test_nextCastTime() public {
        hevm.warp(1606161600); // Nov 23, 20 UTC (could be cast Nov 26)

        vote(address(spell));
        spell.schedule();

        uint256 monday_1400_UTC = 1606744800; // Nov 30, 2020
        uint256 monday_2100_UTC = 1606770000; // Nov 30, 2020

        // Day tests
        hevm.warp(monday_1400_UTC);                                    // Monday,   14:00 UTC
        assertEq(spell.nextCastTime(), monday_1400_UTC);               // Monday,   14:00 UTC

        if (spell.officeHours()) {
            hevm.warp(monday_1400_UTC - 1 days);                       // Sunday,   14:00 UTC
            assertEq(spell.nextCastTime(), monday_1400_UTC);           // Monday,   14:00 UTC

            hevm.warp(monday_1400_UTC - 2 days);                       // Saturday, 14:00 UTC
            assertEq(spell.nextCastTime(), monday_1400_UTC);           // Monday,   14:00 UTC

            hevm.warp(monday_1400_UTC - 3 days);                       // Friday,   14:00 UTC
            assertEq(spell.nextCastTime(), monday_1400_UTC - 3 days);  // Able to cast

            hevm.warp(monday_2100_UTC);                                // Monday,   21:00 UTC
            assertEq(spell.nextCastTime(), monday_1400_UTC + 1 days);  // Tuesday,  14:00 UTC

            hevm.warp(monday_2100_UTC - 1 days);                       // Sunday,   21:00 UTC
            assertEq(spell.nextCastTime(), monday_1400_UTC);           // Monday,   14:00 UTC

            hevm.warp(monday_2100_UTC - 2 days);                       // Saturday, 21:00 UTC
            assertEq(spell.nextCastTime(), monday_1400_UTC);           // Monday,   14:00 UTC

            hevm.warp(monday_2100_UTC - 3 days);                       // Friday,   21:00 UTC
            assertEq(spell.nextCastTime(), monday_1400_UTC);           // Monday,   14:00 UTC

            // Time tests
            uint256 castTime;

            for(uint256 i = 0; i < 5; i++) {
                castTime = monday_1400_UTC + i * 1 days; // Next day at 14:00 UTC
                hevm.warp(castTime - 1 seconds); // 13:59:59 UTC
                assertEq(spell.nextCastTime(), castTime);

                hevm.warp(castTime + 7 hours + 1 seconds); // 21:00:01 UTC
                if (i < 4) {
                    assertEq(spell.nextCastTime(), monday_1400_UTC + (i + 1) * 1 days); // Next day at 14:00 UTC
                } else {
                    assertEq(spell.nextCastTime(), monday_1400_UTC + 7 days); // Next monday at 14:00 UTC (friday case)
                }
            }
        }
    }

    function testFail_notScheduled() public view {
        spell.nextCastTime();
    }

    function test_use_eta() public {
        hevm.warp(1606161600); // Nov 23, 20 UTC (could be cast Nov 26)

        vote(address(spell));
        spell.schedule();

        uint256 castTime = spell.nextCastTime();
        assertEq(castTime, spell.eta());
    }

    function test_OSMs() public { // make public to use
        address READER_ADDR = address(spotter);

        // Track OSM authorizations here
        assertEq(OsmAbstract(addr.addr("PIP_CRVV1ETHSTETH")).bud(READER_ADDR), 0);

        vote(address(spell));
        scheduleWaitAndCast(address(spell));
        assertTrue(spell.done());

        assertEq(OsmAbstract(addr.addr("PIP_CRVV1ETHSTETH")).bud(READER_ADDR), 1);
    }

    function test_Medianizers() public { // make public to use
        vote(address(spell));
        scheduleWaitAndCast(address(spell));
        assertTrue(spell.done());

        // Track Median authorizations here
        address SET_TOKEN    = addr.addr("PIP_CRVV1ETHSTETH");
        address ETHUSD_MED   = CurveLPOsmLike(SET_TOKEN).orbs(0);
        address STETHUSD_MED = CurveLPOsmLike(SET_TOKEN).orbs(1);
        assertEq(MedianAbstract(ETHUSD_MED).bud(SET_TOKEN), 1);
        assertEq(MedianAbstract(STETHUSD_MED).bud(SET_TOKEN), 1);
        assertEq(MedianAbstract(OsmAbstract(addr.addr("PIP_WSTETH")).src()).bud(STETHUSD_MED), 1);
    }

    function test_auth() public { // make public to use
        checkAuth(false);
    }

    function test_auth_in_sources() public { // make public to use
        checkAuth(true);
    }

    // Verifies that the bytecode of the action of the spell used for testing
    // matches what we'd expect.
    //
    // Not a complete replacement for Etherscan verification, unfortunately.
    // This is because the DssSpell bytecode is non-deterministic because it
    // deploys the action in its constructor and incorporates the action
    // address as an immutable variable--but the action address depends on the
    // address of the DssSpell which depends on the address+nonce of the
    // deploying address. If we had a way to simulate a contract creation by
    // an arbitrary address+nonce, we could verify the bytecode of the DssSpell
    // instead.
    //
    // Vacuous until the deployed_spell value is non-zero.
    function test_bytecode_matches() public {
        address expectedAction = (new DssSpell()).action();
        address actualAction   = spell.action();
        uint256 expectedBytecodeSize;
        uint256 actualBytecodeSize;
        assembly {
            expectedBytecodeSize := extcodesize(expectedAction)
            actualBytecodeSize   := extcodesize(actualAction)
        }

        uint256 metadataLength = getBytecodeMetadataLength(expectedAction);
        assertTrue(metadataLength <= expectedBytecodeSize);
        expectedBytecodeSize -= metadataLength;

        metadataLength = getBytecodeMetadataLength(actualAction);
        assertTrue(metadataLength <= actualBytecodeSize);
        actualBytecodeSize -= metadataLength;

        assertEq(actualBytecodeSize, expectedBytecodeSize);
        uint256 size = actualBytecodeSize;
        uint256 expectedHash;
        uint256 actualHash;
        assembly {
            let ptr := mload(0x40)

            extcodecopy(expectedAction, ptr, 0, size)
            expectedHash := keccak256(ptr, size)

            extcodecopy(actualAction, ptr, 0, size)
            actualHash := keccak256(ptr, size)
        }
        assertEq(expectedHash, actualHash);
    }

    function setFlaps() internal {
        vote(address(spell));
        scheduleWaitAndCast(address(spell));
        assertTrue(spell.done());
        // Force creation of 1B surplus
        hevm.store(
            address(vat),
            bytes32(uint256(keccak256(abi.encode(address(vow), uint256(5))))),
            bytes32(uint256(1_000_000_000 * RAD))
        );
        assertEq(vat.dai(address(vow)), 1_000_000_000 * RAD);
        vow.heal(vat.sin(address(vow)) - vow.Sin() - vow.Ash());
    }

    function test_new_flapper() public {
        setFlaps();

        assertEq(vow.flapper(), addr.addr("MCD_FLAP"));
        assertEq(address(flap), addr.addr("MCD_FLAP"));

        assertEq(flap.fill(), 0);
        vow.flap();
        assertEq(flap.fill(), 30_000 * RAD);
        vow.flap();
        assertEq(flap.fill(), 60_000 * RAD);
        vow.flap();
        assertEq(flap.fill(), 90_000 * RAD);
        vow.flap();
        assertEq(flap.fill(), 120_000 * RAD);
        vow.flap();
        assertEq(flap.fill(), 150_000 * RAD);
    }

    function testFail_new_flapper_exeed_limit() public {
        test_new_flapper();
        vow.flap();
    }

}