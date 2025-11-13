import tw from 'twin.macro';
import { createGlobalStyle } from 'styled-components/macro';

export default createGlobalStyle`
    body {
        ${tw`font-sans`};
        background: radial-gradient(circle at top, #0a1530 0%, #050910 60%, #02060d 100%) fixed;
        color: #dae4ff;
        letter-spacing: 0.015em;
    }

    h1, h2, h3, h4, h5, h6 {
        ${tw`font-medium tracking-normal font-header`};
        color: #f3f6ff;
    }

    p {
        ${tw`leading-snug font-sans`};
        color: rgba(218, 228, 255, 0.82);
    }

    a {
        color: #65a4ff;
    }

    a:hover {
        color: #3f83f5;
    }

    .text-neutral-200 { color: #dce6ff !important; }
    .text-neutral-300 { color: #c2d4ff !important; }
    .text-neutral-500 { color: #93a7cf !important; }
    .text-neutral-600 { color: #7b8cb3 !important; }

    .bg-neutral-900 {
        background: rgba(10, 20, 37, 0.85) !important;
        backdrop-filter: blur(12px);
        border: 1px solid rgba(31, 111, 235, 0.15);
    }

    .bg-neutral-800 {
        background: rgba(10, 24, 46, 0.72) !important;
        backdrop-filter: blur(10px);
        border: 1px solid rgba(31, 111, 235, 0.12);
    }

    .bg-neutral-700 {
        background: rgba(12, 30, 56, 0.6) !important;
        backdrop-filter: blur(8px);
        border: 1px solid rgba(31, 111, 235, 0.1);
    }

    .bg-gray-900 {
        background: rgba(5, 12, 24, 0.85) !important;
    }

    .bg-gray-800 {
        background: rgba(6, 16, 32, 0.7) !important;
    }

    .border-neutral-700 {
        border-color: rgba(31, 111, 235, 0.25) !important;
    }

    .shadow,
    .shadow-md,
    .shadow-lg,
    .shadow-xl,
    .shadow-2xl {
        box-shadow: 0 18px 50px rgba(4, 10, 20, 0.45) !important;
    }

    form {
        ${tw`m-0`};
    }

    textarea, select, input, button, button:focus, button:focus-visible {
        ${tw`outline-none`};
    }

    input[type=number]::-webkit-outer-spin-button,
    input[type=number]::-webkit-inner-spin-button {
        -webkit-appearance: none !important;
        margin: 0;
    }

    input[type=number] {
        -moz-appearance: textfield !important;
    }

    /* Scroll Bar Style */
    ::-webkit-scrollbar {
        background: none;
        width: 16px;
        height: 16px;
    }

    ::-webkit-scrollbar-thumb {
        border: solid 0 rgb(0 0 0 / 0%);
        border-right-width: 4px;
        border-left-width: 4px;
        -webkit-border-radius: 9px 4px;
        -webkit-box-shadow: inset 0 0 0 1px rgba(123, 153, 215, 0.35), inset 0 0 0 4px rgba(54, 90, 150, 0.55);
    }

    ::-webkit-scrollbar-track-piece {
        margin: 4px 0;
    }

    ::-webkit-scrollbar-thumb:horizontal {
        border-right-width: 0;
        border-left-width: 0;
        border-top-width: 4px;
        border-bottom-width: 4px;
        -webkit-border-radius: 4px 9px;
    }

    ::-webkit-scrollbar-corner {
        background: transparent;
    }
`;
