import styled from 'styled-components/macro';
import tw from 'twin.macro';

const SubNavigation = styled.div`
    ${tw`w-full overflow-x-auto`};
    background: linear-gradient(
        135deg,
        rgba(12, 28, 54, 0.92) 0%,
        rgba(7, 18, 36, 0.92) 65%,
        rgba(5, 12, 26, 0.95) 100%
    );
    border-bottom: 1px solid rgba(31, 111, 235, 0.22);
    box-shadow: 0 18px 50px rgba(4, 10, 20, 0.35);
    backdrop-filter: blur(12px);

    & > div {
        ${tw`flex items-center text-sm mx-auto px-2`};
        max-width: 1200px;

        & > a,
        & > div {
            ${tw`inline-block py-3 px-4 no-underline whitespace-nowrap transition-all duration-150`};
            color: rgba(206, 220, 255, 0.78);

            &:not(:first-of-type) {
                ${tw`ml-2`};
            }

            &:hover {
                color: #eff3ff;
                background: rgba(31, 111, 235, 0.12);
            }

            &:active,
            &.active {
                color: #f6f8ff;
                box-shadow: inset 0 -3px rgba(31, 111, 235, 0.82);
            }
        }
    }
`;

export default SubNavigation;
