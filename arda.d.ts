declare module Arda {
  // Promise
  export interface Thenable<R> {
    then<U>(onFulfilled?: (value: R) => Thenable<U>, onRejected?: (error: any) => Thenable<U>): Thenable<U>;
    then<U>(onFulfilled?: (value: R) => Thenable<U>, onRejected?: (error: any) => U): Thenable<U>;
    then<U>(onFulfilled?: (value: R) => Thenable<U>, onRejected?: (error: any) => void): Thenable<U>;
    then<U>(onFulfilled?: (value: R) => U, onRejected?: (error: any) => Thenable<U>): Thenable<U>;
    then<U>(onFulfilled?: (value: R) => U, onRejected?: (error: any) => U): Thenable<U>;
    then<U>(onFulfilled?: (value: R) => U, onRejected?: (error: any) => void): Thenable<U>;
  }

  export class Router {
    constructor(layout: Component<any, any>, el: HTMLElement);
    pushState(context: typeof Context, args?: any): Thenable<Context<any, any, any>>;
    replaceState(context: typeof Context, args?: any): Thenable<Context<any, any, any>>;
    popState(): Thenable<Context<any, any, any>>;
  }

  export class Component<TemplateProps, InternalState> {
    props: TemplateProps;
    state: InternalState;
    render(): void;
  }

  export class Context<Props, State, TemplateProps>
  extends Component<TemplateProps, any> {
    static rootComponent: typeof Component;
    static subscribers: Function[];
    initState(p: Props): State | Thenable<State>;
    expandTemplate(p: Props, s: State): TemplateProps | Thenable<TemplateProps>;
    update(updater: (s: State)=> State): Thenable<any>;
  }
}