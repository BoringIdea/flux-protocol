// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @notice On-chain frog hats, hair, accessories and Genesis badge.
contract FrogHeadRenderer {
    string internal constant O = "#101610";

    function renderHead(uint16 bodyStyle, uint16 headStyle) external pure returns (string memory) {
        (string memory light, string memory a) = _palette(bodyStyle);
        return _head(headStyle % 18, light, a);
    }

    function renderAccessory(uint16 bodyStyle, uint16 accessoryStyle)
        external
        pure
        returns (string memory)
    {
        (string memory light, string memory a) = _palette(bodyStyle);
        return _accessory(accessoryStyle % 6, light, a);
    }

    function genesisMark() external pure returns (string memory) {
        return
        '<g id="genesis-mark"><rect x="3" y="3" width="7" height="7" fill="#FF63CE"/><rect x="4" y="4" width="5" height="5" fill="#101610"/><rect x="5" y="5" width="3" height="3" fill="#C9FF59"/><rect x="7" y="5" width="1" height="1" fill="#F7FFF3"/></g>';
    }

    function _palette(uint16 value) internal pure returns (string memory light, string memory a) {
        uint256 i = value % 12;
        string[12] memory lights = [
            "#C9FF59",
            "#8CFFC1",
            "#8DF3FF",
            "#FFF29B",
            "#D8C2FF",
            "#FFB29E",
            "#FFFFFF",
            "#748292",
            "#FFD0E2",
            "#87A8FF",
            "#E6FF70",
            "#D89A6F"
        ];
        string[12] memory accents = [
            "#FF4FC3",
            "#8B5CF6",
            "#FF5B45",
            "#5B4BE1",
            "#FFE552",
            "#55E6D3",
            "#E94B64",
            "#FFB84D",
            "#4ED6C5",
            "#FFB13B",
            "#9A55E8",
            "#46CFE0"
        ];
        return (lights[i], accents[i]);
    }

    function _head(uint256 style, string memory light, string memory a)
        internal
        pure
        returns (string memory)
    {
        if (style == 0) return "";
        if (style == 1) {
            return string.concat(
                '<g id="party-hat" fill="',
                O,
                '"><rect x="23" y="2" width="3" height="3"/><rect x="21" y="4" width="7" height="4"/><rect x="19" y="7" width="11" height="4"/><rect x="17" y="10" width="15" height="4"/></g><g fill="',
                a,
                '"><rect x="24" y="2" width="2" height="3"/><rect x="22" y="5" width="5" height="2"/><rect x="20" y="8" width="9" height="2"/><rect x="18" y="11" width="13" height="2"/></g>'
            );
        }
        if (style == 2) {
            return string.concat(
                '<g id="crown" fill="',
                O,
                '"><rect x="17" y="6" width="15" height="7"/><rect x="17" y="3" width="4" height="5"/><rect x="23" y="2" width="3" height="6"/><rect x="29" y="3" width="3" height="5"/></g><g fill="',
                a,
                '"><rect x="18" y="5" width="3" height="6"/><rect x="22" y="7" width="5" height="4"/><rect x="28" y="5" width="3" height="6"/></g>'
            );
        }
        if (style == 3) {
            return string.concat(
                '<g id="sprout" fill="',
                O,
                '"><rect x="23" y="5" width="3" height="9"/><rect x="15" y="3" width="9" height="5"/><rect x="26" y="2" width="9" height="5"/></g><g fill="',
                light,
                '"><rect x="16" y="4" width="7" height="3"/><rect x="27" y="3" width="7" height="3"/></g>'
            );
        }
        if (style == 4) {
            return string.concat(
                '<g id="wizard-hat" fill="',
                O,
                '"><rect x="20" y="2" width="9" height="3"/><rect x="18" y="5" width="13" height="4"/><rect x="16" y="8" width="17" height="5"/><rect x="13" y="12" width="23" height="3"/></g><g fill="',
                a,
                '"><rect x="22" y="3" width="6" height="2"/><rect x="20" y="6" width="10" height="3"/><rect x="18" y="9" width="14" height="3"/><rect x="15" y="13" width="19" height="1"/></g>'
            );
        }
        if (style == 5) {
            return string.concat(
                '<g id="mushroom-cap" fill="',
                O,
                '"><rect x="18" y="4" width="12" height="2"/><rect x="15" y="6" width="18" height="3"/><rect x="13" y="9" width="22" height="4"/><rect x="16" y="13" width="16" height="2"/></g><g fill="',
                a,
                '"><rect x="19" y="5" width="10" height="2"/><rect x="16" y="7" width="16" height="3"/><rect x="14" y="10" width="20" height="2"/></g>'
            );
        }
        if (style == 6) {
            return string.concat(
                '<g id="halo" fill="',
                O,
                '"><rect x="15" y="5" width="18" height="3"/></g><rect x="17" y="6" width="14" height="1" fill="',
                a,
                '"/>'
            );
        }
        if (style == 7) {
            return
            '<g id="viking-horns" fill="#101610"><rect x="16" y="8" width="16" height="6"/><rect x="11" y="7" width="6" height="5"/><rect x="31" y="7" width="6" height="5"/></g><rect x="17" y="9" width="14" height="4" fill="#84939B"/><g fill="#F2E6C9"><rect x="10" y="6" width="3" height="2"/><rect x="12" y="8" width="4" height="3"/><rect x="36" y="6" width="3" height="2"/><rect x="32" y="8" width="4" height="3"/></g>';
        }
        if (style == 8) {
            return string.concat(
                '<g id="beanie" fill="',
                O,
                '"><rect x="18" y="4" width="12" height="2"/><rect x="15" y="6" width="18" height="7"/><rect x="13" y="12" width="22" height="3"/></g><g fill="',
                a,
                '"><rect x="19" y="5" width="10" height="2"/><rect x="16" y="7" width="16" height="5"/><rect x="15" y="13" width="18" height="1"/></g>'
            );
        }
        if (style == 9) {
            return string.concat(
                '<g id="lotus" fill="',
                O,
                '"><rect x="22" y="7" width="5" height="7"/><rect x="16" y="8" width="7" height="6"/><rect x="27" y="8" width="7" height="6"/></g><g fill="',
                a,
                '"><rect x="23" y="8" width="3" height="5"/><rect x="17" y="9" width="5" height="4"/><rect x="28" y="9" width="5" height="4"/></g>'
            );
        }
        if (style == 10) {
            return string.concat(
                '<g id="baseball-cap" fill="',
                O,
                '"><rect x="16" y="6" width="17" height="7"/><rect x="14" y="9" width="4" height="5"/><rect x="31" y="11" width="9" height="3"/></g><g fill="',
                a,
                '"><rect x="17" y="7" width="15" height="5"/><rect x="15" y="10" width="3" height="3"/><rect x="31" y="12" width="7" height="1"/></g>'
            );
        }
        if (style == 11) {
            return string.concat(
                '<g id="top-hat" fill="',
                O,
                '"><rect x="18" y="2" width="13" height="10"/><rect x="14" y="11" width="21" height="4"/></g><rect x="19" y="3" width="11" height="7" fill="#252A27"/><rect x="19" y="8" width="11" height="2" fill="',
                a,
                '"/>'
            );
        }
        if (style == 12) {
            return string.concat(
                '<g id="cowboy-hat" fill="',
                O,
                '"><rect x="18" y="5" width="13" height="7"/><rect x="14" y="8" width="5" height="5"/><rect x="30" y="8" width="5" height="5"/><rect x="10" y="12" width="29" height="3"/></g><g fill="#A86632"><rect x="19" y="6" width="11" height="5"/><rect x="12" y="13" width="25" height="1"/></g>'
            );
        }
        if (style == 13) {
            return string.concat(
                '<g id="bucket-hat" fill="',
                O,
                '"><rect x="17" y="6" width="15" height="6"/><rect x="14" y="10" width="21" height="5"/><rect x="11" y="13" width="27" height="3"/></g><g fill="',
                a,
                '"><rect x="18" y="7" width="13" height="4"/><rect x="16" y="11" width="17" height="3"/><rect x="13" y="14" width="23" height="1"/></g>'
            );
        }
        if (style == 14) {
            return string.concat(
                '<g id="mohawk" fill="',
                O,
                '"><rect x="22" y="2" width="6" height="13"/><rect x="19" y="5" width="4" height="4"/><rect x="27" y="7" width="4" height="4"/></g><rect x="24" y="2" width="3" height="12" fill="',
                a,
                '"/>'
            );
        }
        if (style == 15) {
            return
            '<g id="afro" fill="#101610"><rect x="14" y="5" width="21" height="10"/><rect x="17" y="2" width="15" height="4"/><rect x="11" y="8" width="5" height="8"/><rect x="33" y="7" width="5" height="9"/></g><g fill="#4A2C20"><rect x="16" y="6" width="17" height="7"/><rect x="18" y="3" width="13" height="4"/></g>';
        }
        if (style == 16) {
            return
            '<g id="side-part" fill="#101610"><rect x="13" y="7" width="23" height="8"/><rect x="11" y="11" width="7" height="9"/><rect x="31" y="10" width="6" height="7"/></g><g fill="#8B5738"><rect x="15" y="8" width="19" height="5"/><rect x="13" y="12" width="5" height="6"/></g>';
        }
        return
        '<g id="long-hair" fill="#101610"><rect x="13" y="6" width="23" height="9"/><rect x="10" y="11" width="8" height="18"/><rect x="31" y="11" width="8" height="18"/></g><g fill="#5A3525"><rect x="15" y="7" width="19" height="6"/><rect x="12" y="12" width="5" height="16"/><rect x="32" y="12" width="5" height="16"/></g>';
    }

    function _accessory(uint256 style, string memory light, string memory a)
        internal
        pure
        returns (string memory)
    {
        if (style == 0) return "";
        if (style == 1) {
            return string.concat(
                '<g id="sparkle" fill="',
                a,
                '"><rect x="41" y="7" width="2" height="10"/><rect x="37" y="11" width="10" height="2"/><rect x="42" y="4" width="1" height="3"/></g>'
            );
        }
        if (style == 2) {
            return string.concat(
                '<g id="bow-tie" fill="',
                O,
                '"><rect x="15" y="32" width="8" height="7"/><rect x="25" y="32" width="8" height="7"/><rect x="22" y="34" width="5" height="6"/></g><g fill="',
                a,
                '"><rect x="16" y="33" width="6" height="5"/><rect x="26" y="33" width="6" height="5"/></g>'
            );
        }
        if (style == 3) {
            return string.concat(
                '<g id="cheeks" fill="',
                a,
                '"><rect x="10" y="26" width="4" height="2"/><rect x="34" y="26" width="4" height="2"/></g>'
            );
        }
        if (style == 4) {
            return string.concat(
                '<g id="fly-friend" fill="',
                O,
                '"><rect x="41" y="20" width="3" height="3"/><rect x="39" y="19" width="2" height="2"/><rect x="44" y="18" width="2" height="2"/></g>'
            );
        }
        light;
        return
        '<g id="gold-chain" fill="#101610"><rect x="16" y="29" width="3" height="2"/><rect x="19" y="30" width="3" height="2"/><rect x="22" y="31" width="5" height="2"/><rect x="27" y="30" width="3" height="2"/><rect x="30" y="29" width="3" height="2"/><rect x="22" y="33" width="5" height="4"/></g><g fill="#FFE552"><rect x="17" y="29" width="2" height="1"/><rect x="20" y="30" width="2" height="1"/><rect x="23" y="31" width="3" height="1"/><rect x="23" y="34" width="3" height="2"/></g>';
    }
}
