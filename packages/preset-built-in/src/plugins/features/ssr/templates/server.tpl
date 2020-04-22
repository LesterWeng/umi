// umi.server.js
import { renderServer, createServerElement } from '{{{ Renderer }}}';
import { findRoute, serialize } from '{{{ Utils }}}'
import { routes } from '@@/core/routes'

export interface IParams {
  path: string;
  initialData?: object;
  htmlTemplate?: string;
  mountElementId?: string;
  context?: object
}

export interface IRenderResult<T> {
  rootContainer: T;
  html?: T;
  error?: Error;
}

export interface IRender<T = string> {
  (params: IParams): Promise<IRenderResult<T>>;
}

export interface IGetInitialProps {

}

export interface IGetInitialPropsServer extends IGetInitialProps {
  isServer: Boolean;
  match: object;
}

/**
 * get current page component getPageInitialProps data
 * @param params
 */
export const getPageInitialProps = async (params) => {
  const { path } = params;
  // pages getInitialProps
  let { component, ...restRouteParams } = findRoute(routes, path) || {};
  let pageInitialProps = {};
  // handle preload dynamic import
  if (component?.preload) {
    component = await component.preload();
  }
  pageInitialProps =
  component?.getInitialProps
      ? await component.getInitialProps({
          isServer: true,
          ...restRouteParams,
        })
      : null;
  return pageInitialProps;
}

/**
 * handle html with rootContainer(rendered)
 * @param param0
 */
export const handleHtml = ({ html, pageInitialProps, rootContainer, mountElementId = 'root' }) => {
  return html
    .replace(
      '</head>',
      `<script>
        window.g_useSSR = true;
        ${pageInitialProps && !{{{ ForceInitialProps }}} ? `window.g_initialProps = ${serialize(pageInitialProps)};` : ''}
      </script>
      </head>`
    )
    .replace(
      `<div id="${mountElementId}"></div>`,
      `<div id="${mountElementId}">${rootContainer}</div>`
    )
}

/**
 * server render function
 * @param params
 */
export const render: IRender = async (params) => {
  let error;
  const { path, initialData, htmlTemplate = '', mountElementId = 'root', context = {} } = params;

  // pages getInitialProps
  const pageInitialProps = await getPageInitialProps({
    path,
  });

  let html = htmlTemplate;
  let rootContainer = '';
  try {
    const opts = {
      path,
      initialData,
      pageInitialProps,
      context,
      routes,
    }
    // renderServer get rootContainer
    rootContainer = await renderServer(opts);
    if (html) {
      html = handleHtml({ html, rootContainer, pageInitialProps, mountElementId });
    }
  } catch (e) {
    // downgrade into csr
    error = e;
    console.error('[SSR ERROR]', e);
  }

  return {
    rootContainer,
    error,
    html,
  }
}

export { createServerElement }