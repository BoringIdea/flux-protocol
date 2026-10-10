// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @notice On-chain frog eyes, glasses and mouth props.
contract FrogFaceRenderer {
    string internal constant O = "#101610";

    function renderEyes(uint16 bodyStyle, uint16 eyeStyle) external pure returns (string memory) {
        (string memory body, string memory light, string memory a) = _palette(bodyStyle);
        return string.concat(_eyeBase(body), _eyes(eyeStyle % 16, light, a));
    }

    function renderMouth(uint16 bodyStyle, uint16 mouthStyle)
        external
        pure
        returns (string memory)
    {
        (, string memory light, string memory a) = _palette(bodyStyle);
        return _mouth(mouthStyle % 16, light, a);
    }

    function _palette(uint16 value)
        internal
        pure
        returns (string memory body, string memory light, string memory a)
    {
        uint256 i = value % 12;
        string[12] memory bodies = [
            "#91DB22",
            "#32D583",
            "#21C7D9",
            "#F2C94C",
            "#A77BFF",
            "#FF7A59",
            "#E8F2E8",
            "#34414F",
            "#F08DB7",
            "#4169D8",
            "#B6F000",
            "#89563D"
        ];
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
        return (bodies[i], lights[i], accents[i]);
    }

    function _eyeBase(string memory body) internal pure returns (string memory) {
        return string.concat(
            '<g id="eye-safe-zone" fill="',
            O,
            '"><rect x="12" y="12" width="10" height="10"/><rect x="26" y="12" width="10" height="10"/></g>',
            '<g fill="',
            body,
            '"><rect x="13" y="13" width="8" height="9"/><rect x="27" y="13" width="8" height="9"/></g>'
        );
    }

    function _normalEyes(string memory light) internal pure returns (string memory) {
        return string.concat(
            '<g fill="#F7FFF3"><rect x="15" y="15" width="4" height="5"/><rect x="29" y="15" width="4" height="5"/></g>',
            '<g fill="',
            O,
            '"><rect x="17" y="16" width="2" height="4"/><rect x="29" y="16" width="2" height="4"/></g>',
            '<g fill="',
            light,
            '"><rect x="17" y="16" width="1" height="1"/><rect x="29" y="16" width="1" height="1"/></g>'
        );
    }

    function _eyes(uint256 style, string memory light, string memory a)
        internal
        pure
        returns (string memory)
    {
        if (style == 0) return string.concat('<g id="round-eyes">', _normalEyes(light), "</g>");
        if (style == 1) {
            return string.concat(
                '<g id="sleepy-eyes" fill="',
                O,
                '"><rect x="13" y="15" width="8" height="2"/><rect x="27" y="15" width="8" height="2"/><rect x="15" y="17" width="5" height="1"/><rect x="28" y="17" width="5" height="1"/></g>'
            );
        }
        if (style == 2) {
            return string.concat(
                '<g id="star-eyes">',
                _normalEyes(light),
                '<g fill="',
                a,
                '"><rect x="16" y="14" width="2" height="6"/><rect x="14" y="16" width="6" height="2"/><rect x="30" y="14" width="2" height="6"/><rect x="28" y="16" width="6" height="2"/></g></g>'
            );
        }
        if (style == 3) {
            return string.concat(
                '<g id="goggles">',
                _normalEyes(light),
                '<g fill="',
                O,
                '"><rect x="11" y="13" width="12" height="2"/><rect x="11" y="20" width="12" height="2"/><rect x="25" y="13" width="12" height="2"/><rect x="25" y="20" width="12" height="2"/><rect x="22" y="16" width="4" height="2"/></g></g>'
            );
        }
        if (style == 4) {
            return string.concat(
                '<g id="angry-eyes">',
                _normalEyes(light),
                '<g fill="',
                O,
                '"><rect x="13" y="13" width="8" height="2"/><rect x="27" y="13" width="8" height="2"/></g></g>'
            );
        }
        if (style == 5) {
            return string.concat(
                '<g id="happy-eyes" fill="',
                O,
                '"><rect x="14" y="17" width="2" height="2"/><rect x="16" y="15" width="3" height="2"/><rect x="19" y="17" width="2" height="2"/><rect x="27" y="17" width="2" height="2"/><rect x="29" y="15" width="3" height="2"/><rect x="32" y="17" width="2" height="2"/></g>'
            );
        }
        if (style == 6) {
            return string.concat(
                '<g id="hypnotic-eyes">',
                _normalEyes(light),
                '<g fill="',
                a,
                '"><rect x="15" y="15" width="4" height="1"/><rect x="15" y="19" width="4" height="1"/><rect x="29" y="15" width="4" height="1"/><rect x="29" y="19" width="4" height="1"/></g></g>'
            );
        }
        if (style == 7) {
            return string.concat(
                '<g id="laser-visor">',
                _normalEyes(light),
                '<g fill="',
                O,
                '"><rect x="11" y="13" width="26" height="2"/><rect x="11" y="20" width="26" height="2"/><rect x="22" y="15" width="4" height="2"/></g><g fill="',
                a,
                '" opacity=".48"><rect x="13" y="15" width="9" height="5"/><rect x="26" y="15" width="9" height="5"/></g></g>'
            );
        }
        if (style == 8) {
            return string.concat(
                '<g id="sunglasses" fill="',
                O,
                '"><rect x="12" y="14" width="11" height="7"/><rect x="25" y="14" width="11" height="7"/><rect x="22" y="16" width="4" height="2"/></g><g fill="#33413A"><rect x="14" y="16" width="7" height="3"/><rect x="27" y="16" width="7" height="3"/></g>'
            );
        }
        if (style == 9) {
            return string.concat(
                '<g id="monocle">',
                _normalEyes(light),
                '<g fill="',
                O,
                '"><rect x="26" y="12" width="10" height="2"/><rect x="26" y="20" width="10" height="2"/><rect x="35" y="14" width="2" height="13"/></g></g>'
            );
        }
        if (style == 10) {
            return string.concat(
                '<g id="three-d-glasses" fill="',
                O,
                '"><rect x="11" y="14" width="12" height="7"/><rect x="25" y="14" width="12" height="7"/><rect x="22" y="16" width="4" height="2"/></g><g fill="#FF5B5B"><rect x="13" y="16" width="8" height="3"/></g><g fill="#59D8FF"><rect x="27" y="16" width="8" height="3"/></g>'
            );
        }
        if (style == 11) {
            return string.concat(
                '<g id="heart-glasses" fill="',
                O,
                '"><rect x="12" y="14" width="10" height="5"/><rect x="14" y="19" width="6" height="3"/><rect x="26" y="14" width="10" height="5"/><rect x="28" y="19" width="6" height="3"/></g><g fill="',
                a,
                '"><rect x="14" y="15" width="6" height="4"/><rect x="28" y="15" width="6" height="4"/></g>'
            );
        }
        if (style == 12) {
            return string.concat(
                '<g id="nerd-glasses">',
                _normalEyes(light),
                '<g fill="',
                O,
                '"><rect x="12" y="13" width="11" height="2"/><rect x="12" y="20" width="11" height="2"/><rect x="25" y="13" width="11" height="2"/><rect x="25" y="20" width="11" height="2"/><rect x="23" y="16" width="2" height="2"/></g></g>'
            );
        }
        if (style == 13) {
            return string.concat(
                '<g id="eye-patch">',
                _normalEyes(light),
                '<g fill="',
                O,
                '"><rect x="12" y="12" width="24" height="2"/><rect x="27" y="14" width="8" height="7"/></g></g>'
            );
        }
        if (style == 14) {
            return string.concat(
                '<g id="aviators" fill="',
                O,
                '"><rect x="12" y="13" width="11" height="8"/><rect x="25" y="13" width="11" height="8"/><rect x="22" y="15" width="4" height="2"/></g><g fill="#C98A52" opacity=".72"><rect x="14" y="15" width="7" height="4"/><rect x="27" y="15" width="7" height="4"/></g>'
            );
        }
        return string.concat(
            '<g id="pixel-shades" fill="',
            O,
            '"><rect x="11" y="14" width="26" height="3"/><rect x="13" y="17" width="9" height="4"/><rect x="26" y="17" width="9" height="4"/></g>'
        );
    }

    function _mouth(uint256 style, string memory light, string memory a)
        internal
        pure
        returns (string memory)
    {
        if (style == 0) {
            return string.concat(
                '<g id="soft-smile" fill="',
                O,
                '"><rect x="14" y="23" width="20" height="2"/><rect x="16" y="25" width="16" height="2"/><rect x="18" y="27" width="12" height="1"/></g><rect x="17" y="25" width="14" height="1" fill="',
                a,
                '"/>'
            );
        }
        if (style == 1) {
            return string.concat(
                '<g id="flat-mouth" fill="', O, '"><rect x="15" y="24" width="18" height="2"/></g>'
            );
        }
        if (style == 2) {
            return string.concat(
                '<g id="big-grin" fill="',
                O,
                '"><rect x="14" y="23" width="20" height="2"/><rect x="16" y="25" width="16" height="4"/></g><rect x="17" y="25" width="14" height="2" fill="#F7FFF3"/><rect x="20" y="28" width="8" height="1" fill="#E96A9D"/>'
            );
        }
        if (style == 3) {
            return string.concat(
                '<g id="tongue-mouth" fill="',
                O,
                '"><rect x="14" y="23" width="20" height="2"/><rect x="16" y="25" width="16" height="3"/><rect x="20" y="28" width="8" height="4"/></g><rect x="21" y="27" width="6" height="4" fill="#F08DB7"/>'
            );
        }
        if (style == 4) {
            return string.concat(
                '<g id="fang-mouth" fill="',
                O,
                '"><rect x="14" y="23" width="20" height="2"/><rect x="16" y="25" width="16" height="3"/></g><g fill="#F7FFF3"><rect x="17" y="25" width="3" height="4"/><rect x="28" y="25" width="3" height="4"/></g>'
            );
        }
        if (style == 5) {
            return string.concat(
                '<g id="ooh-mouth" fill="',
                O,
                '"><rect x="20" y="23" width="8" height="2"/><rect x="18" y="25" width="12" height="5"/></g><rect x="21" y="26" width="6" height="3" fill="',
                a,
                '"/>'
            );
        }
        if (style == 6) {
            return string.concat(
                '<g id="smirk-mouth" fill="',
                O,
                '"><rect x="15" y="25" width="15" height="2"/><rect x="29" y="23" width="4" height="2"/></g>'
            );
        }
        if (style == 7) {
            return string.concat(
                '<g id="bubblegum-mouth"><rect x="14" y="24" width="14" height="2" fill="',
                O,
                '"/><rect x="27" y="22" width="8" height="8" fill="',
                O,
                '"/><rect x="28" y="23" width="6" height="6" fill="',
                a,
                '"/></g>'
            );
        }
        if (style == 8) {
            return string.concat(
                '<g id="gold-tooth" fill="',
                O,
                '"><rect x="15" y="23" width="18" height="2"/><rect x="17" y="25" width="14" height="4"/></g><rect x="18" y="25" width="12" height="2" fill="#F7FFF3"/><rect x="23" y="25" width="3" height="3" fill="#FFE552"/>'
            );
        }
        if (style == 9) {
            return string.concat(
                '<g id="cigarette-mouth"><rect x="16" y="24" width="15" height="2" fill="',
                O,
                '"/><rect x="30" y="25" width="10" height="2" fill="#F7FFF3"/><rect x="39" y="25" width="3" height="2" fill="#FF754A"/></g>'
            );
        }
        if (style == 10) {
            return string.concat(
                '<g id="cigar-mouth"><rect x="15" y="24" width="17" height="2" fill="',
                O,
                '"/><rect x="31" y="24" width="11" height="4" fill="',
                O,
                '"/><rect x="32" y="25" width="8" height="2" fill="#9A522C"/></g>'
            );
        }
        if (style == 11) {
            return string.concat(
                '<g id="pipe-mouth" fill="',
                O,
                '"><rect x="15" y="24" width="17" height="2"/><rect x="30" y="25" width="7" height="2"/><rect x="37" y="25" width="6" height="6"/></g><rect x="38" y="26" width="4" height="4" fill="#9A5D35"/>'
            );
        }
        if (style == 12) {
            return string.concat(
                '<g id="mustache" fill="',
                O,
                '"><rect x="13" y="24" width="10" height="4"/><rect x="25" y="24" width="10" height="4"/><rect x="11" y="26" width="5" height="2"/><rect x="33" y="26" width="5" height="2"/></g>'
            );
        }
        if (style == 13) {
            return string.concat(
                '<g id="lollipop-mouth"><rect x="15" y="24" width="16" height="2" fill="',
                O,
                '"/><rect x="31" y="25" width="2" height="10" fill="#F7FFF3"/><rect x="29" y="32" width="6" height="6" fill="',
                a,
                '"/></g>'
            );
        }
        if (style == 14) {
            return string.concat(
                '<g id="pacifier"><rect x="18" y="23" width="12" height="2" fill="',
                O,
                '"/><rect x="20" y="25" width="8" height="6" fill="',
                O,
                '"/><rect x="21" y="26" width="6" height="4" fill="',
                a,
                '"/></g>'
            );
        }
        light;
        return string.concat(
            '<g id="rose-stem"><rect x="15" y="24" width="16" height="2" fill="',
            O,
            '"/><rect x="30" y="25" width="10" height="1" fill="#357A48"/><rect x="38" y="21" width="6" height="5" fill="#FF4F6D"/></g>'
        );
    }
}
